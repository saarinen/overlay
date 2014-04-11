require 'github_api'
require 'fileutils'
require 'socket'
require 'singleton'
require 'redis'
require 'net/http'
require 'timeout'

# The github class is responsible for managing overlaying
# directories in a Github repo on the current application.
# Call to action is based on either a webhook call to the github controller
# or a publish event to a redis key.
#
module Overlay
  class Github
    include Singleton
    include Overlay::Engine.routes.url_helpers

    attr_accessor :subscribed_configs

    def initialize
      @subscribed_configs   = []
      @master_pid           = $$
      @current_subscribers  = {}
    end

    # Cycle through all configured repositories and overlay
    # This function should be called only at initialization time as it causes a
    # full overlay to be run
    def process_overlays
      Overlay.configuration.repositories.each do |repo_config|
        next unless repo_config.class == GithubRepo

        # Register this server's endpoint as a webhook or subscribe
        # to a redis pub/sub
        if repo_config.use_publisher
          publisher_subscribe(repo_config)
        else
          register_web_hook(repo_config)
        end

        # Now that all the set-up is done, fork a process
        # to overlay the repo.
        fork_it(:overlay_repo, repo_config)
      end
    end

    # Take a hook hash and process each changelist.
    # For every file updated, clone it back to us.
    def process_hook hook, repo_config
      # Grab the commit array
      commits = hook['commits']

      # We don't care if there aren't commits
      return if commits.nil?

      commits.each do |commit|
        # There will be three entries in each commit with file paths: added, removed, and modified.
        unless commit['added'].nil?
          added_files = commit['added']
          added_files.each do |file|
            # Do we care?
            if my_file?(file, repo_config)
              Rails.logger.info "Overlay found added file in hook: #{file}"

              # Make sure that the directory is in place
              FileUtils.mkdir_p(destination_path(File.dirname(file), repo_config))
              clone_file(file, repo_config)
            end
          end
        end

        unless commit['modified'].nil?
          modified_files = commit['modified']
          modified_files.each do |file|
            # Do we care?
            if my_file?(file, repo_config)
              Rails.logger.info "Overlay found modified file in hook: #{file}"
              clone_file(file, repo_config)
            end
          end
        end

        unless commit['removed'].nil?
          removed_files = commit['removed']
          removed_files.each do |file|
            # Do we care?
            if my_file?(file, repo_config)
              Rails.logger.info "Overlay found deleted file in hook: #{file}"
              File.delete(destination_path(file, repo_config))
            end
          end
        end
      end

      # Call post hook code
      repo_config.post_hook
    end

    private

    # Register our listener on the repo
    #
    def register_web_hook(repo_config)
      Rails.logger.info "Overlay register webhook for repo: org => #{repo_config.org}, repo => #{repo_config.repo}"
      # Make sure our routes are loaded
      Rails.application.reload_routes!

      # Build hook url
      host = config.host_name || ENV['SERVER_HOST_NAME'] || Socket.gethostname
      port = config.host_port || ENV['SERVER_HOST_PORT'] || Rails::Server.new.options[:Port]
      path = Overlay::Engine.routes.url_for({:controller=>"overlay/github", :action=>"update", :only_path => true})
      uri  = ActionDispatch::Http::URL::url_for({:host => host, :port => port, :path => "#{config.relative_root_url}#{path}"})

      github_api = repo_config.github_api

      begin
        timeout(30) {
          # Retrieve current web hooks
          current_hooks = github_api.hooks.list(repo_config.org, repo_config.repo).response.body
          if current_hooks.find {|hook| hook.config.url == uri}.nil?
            # register hook
            github_api.hooks.create(repo_config.org, repo_config.repo, name: 'web', active: true, config: {:url => uri, :content_type => 'json'})
          end
        }
      rescue Timeout::Error
        Rails.logger.info "Overlay timed out while hegistering web hook"
        raise "Overlay timed out while hegistering web hook"
      end
    end

    # Retrieve Subscribe to a OverlayPublisher redis key
    # Fork a process that subscribes to the redis key and processes updates.
    def publisher_subscribe repo_config
      # Is this specific configuration already subscribed?
      return unless @subscribed_configs.index(repo_config).nil?

      # Validate our settings
      repo_config.validate

      begin
        response = timeout(30) {
          # Register this repo with the manager
          uri = ::URI.parse(repo_config.registration_server)
          http = ::Net::HTTP.new(uri.host, uri.port)
          request = ::Net::HTTP::Post.new("/register")
          request.add_field('Content-Type', 'application/json')
          request.body = {
            'organization' => repo_config.org,
            'repo' => repo_config.repo,
            'auth' => repo_config.auth,
            'endpoint' => repo_config.endpoint,
            'site' => repo_config.site
          }.to_json

          http.request(request)
        }
      rescue Timeout::Error
        Rails.logger.info "Overlay timed out while registering with publisher: #{repo_config.registration_server}"
        raise "Overlay timed out while registering with #{repo_config.registration_server}"
      end

      # Retrieve publish key
      publish_key = JSON.parse(response.read_body)['publish_key']

      # If we have a subscriber running for the same key, return
      return if @current_subscribers.has_key? publish_key

      Rails.logger.info "Overlay subscribing to redis channel: #{publish_key}"

      # Subscribe to redis channel
      pid = fork_it(:subscribe_to_channel, publish_key, repo_config)

      @subscribed_configs << repo_config
      @current_subscribers[publish_key] = pid
    end

    # Overlay all the files specifiec by the repo_config.  This
    # process can be long_running so we fork.  We should only be running
    # this method in initialization of the application or on explicit call.
    # This method must succeed to completion to guarantee we have all the files
    # we need so we will continue to retyr until we are complete
    def overlay_repo repo_config
      # Get our root entries
      root = repo_config.root_source_path || '/'

      begin
        Rails.logger.info "Overlay started processing repo with config #{repo_config.inspect}"

        # If we have a root defined, jump right into it
        if root != '/'
          overlay_directory(root, repo_config)
        else
          root_entries = timeout(30) {
             repo_config.github_api.contents.get(repo_config.org, repo_config.repo, root, ref: repo_config.branch).response.body
          }

          # We aren't pulling anything out of root.  Cycle through directories and overlay
          root_entries.each do |entry|
            if entry.type == 'dir'
              overlay_directory(entry.path, repo_config)
            end
          end
        end
      rescue Timeout::Error
        Rails.logger.info "Overlay timed out while retrieving root directories and is retrying"
        sleep 5
        retry
      rescue => e
        Rails.logger.error "Overlay encountered an error during overlay_repo and is retrying: #{e.message}"
        sleep 5
        retry
      end

      Rails.logger.info "Overlay finished processing repo with config #{repo_config.inspect}"
    end

    def overlay_directory path, repo_config
      Rails.logger.info "Overlay processing directory with path: #{path}"
      FileUtils.mkdir_p(destination_path(path, repo_config)) unless File.exists?(destination_path(path, repo_config))

      begin
        Rails.logger.info "Overlay retrieving directory contents for path: #{path}"
        directory_entries = timeout(30) {
          repo_config.github_api.contents.get(repo_config.org, repo_config.repo, path, ref: repo_config.branch).response.body
        }
      rescue Timeout::Error
        Rails.logger.info "Overlay timed out during overlay_directory for path: #{path}"
        raise "Overlay timed out during overlay_directory for path: #{path}"
      end

      directory_entries.each do |entry|
        if entry.type == 'dir'
          overlay_directory(entry.path, repo_config)
        elsif entry.type == 'file'
          clone_file(entry.path, repo_config)
        end
      end
    end

    def clone_file path, repo_config
      Rails.logger.info "Overlay cloning file with path: #{path}"
      begin
        file = timeout(30) {
          repo_config.github_api.contents.get(repo_config.org, repo_config.repo, path, ref: repo_config.branch).response.body.content
        }
      rescue Timeout::Error
        Rails.logger.error "Overlay timed out while cloning file: #{path}"
        raise "Overlay timed out while cloning file: #{path}"
      end

      File.open(destination_path(path, repo_config), "wb") { |f| f.write(Base64.decode64(file)) }
      Rails.logger.info "Overlay cloned file: #{path}"
    end

    # Fork a new process and subscribe to a redis channel
    def subscribe_to_channel key, repo_config
      Rails.logger.info "Overlay establishing connection to Redis server: #{repo_config.redis_server} on port: #{repo_config.redis_port}"
      redis = Redis.new(:host => repo_config.redis_server, :port => repo_config.redis_port)

      # This key is going to receive a publish event
      # for any changes to the target repo.  We need to verify
      # that the payload references our branch and our watch direstory.
      # The subscribe call is persistent.
      begin
        Rails.logger.info "Overlay subscribing to key: #{key}"
        redis.subscribe(key) do |on|
          on.subscribe do |channel, subscriptions|
            Rails.logger.info "'#{channel}' channel subscription established for key '#{key}'. Subscriptions: #{subscriptions}"
          end
          on.message do |channel, msg|
            Rails.logger.info "Overlay received publish event for channel #{key} with payload: #{msg}"
            hook = JSON.parse(msg)

            # We may be receiving hooks for several configured roots.  Since we should only have one subscriber servicing
            # a repo, we need to see if we can handle this hook.  The incoming hook is already keyed to repo and org so we
            # just need to check branch.
            Overlay.configuration.repositories.each do |configured_repo|
              next unless configured_repo.class == GithubRepo
              if (hook['ref'] == "refs/heads/#{configured_repo.branch}")
                Rails.logger.info "Overlay enqueueing Github hook processing job for repo: #{configured_repo.repo} and branch: #{configured_repo.branch}"
                process_hook(hook, configured_repo)
                Rails.logger.info "Overlay done processing job for repo: #{configured_repo.repo} and branch: #{configured_repo.branch}"
              end
            end
          end
        end
        Rails.logger.error "Overlay subscribe closed for unknown reason."
      rescue => e
        Rails.logger.error "Overlay encountered an error during subscribe_to_channel on key #{key} and is retrying: #{e.message}"
        sleep 5
        retry
      end
    end

    def my_file? file_path, repo_config
      return true if repo_config.root_dest_path.empty?
      file_path.starts_with?(repo_config.root_source_path)
    end

    def root_path repo_config
      repo_config.root_dest_path.empty? ? "#{Rails.application.root}" : "#{Rails.application.root}/#{repo_config.root_dest_path}"
    end

    def destination_path file_path, repo_config
      raise "The file #{file_path} isn't handled by this repo with root path: #{repo_config.root_source_path}" unless my_file?(file_path, repo_config)
      dynamic_path = file_path.partition(repo_config.root_source_path).last
      return "#{root_path(repo_config)}#{dynamic_path}"
    end

    def config
      @overlay_config ||= Overlay.configuration
    end

    # Process the passed in function symbol and args in a fork
    # Add at exit hook to insure we kill our process.  Insure we only do this
    # from the master process
    def fork_it method, *args
      pid = Process.fork do
        Signal.trap('QUIT') { puts "Exiting #{method} process."; Process.exit }
        begin
          send(method, *args)
        ensure
          Process.exit
        end
      end
      Process.detach(pid)
      at_exit do
        Process.kill('QUIT', pid) if @master_pid == $$
      end
      return pid
    end
  end
end
