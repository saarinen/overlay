require 'github_api'
require 'fileutils'
require 'socket'

module Overlay
  class Github
    include Overlay::Engine.routes.url_helpers
    # Cycle through all configured repositories and overlay
    #
    def self.process_overlays
      # This can be called in an application initializer which will
      # load anytime the environment is loaded.  Make sure we are prepared to run
      # this.
      #
      return unless (config.host_port || ENV['SERVER_HOST_PORT'] || defined? Rails::Server)

      # Configure github api
      configure

      Overlay.configuration.repositories.each do |repo_config|
        next unless repo_config.class == GithubRepo

        # Validate repository config
        raise 'Respository config missing user' if (!repo_config[:user] || repo_config[:user].nil?)
        raise 'Respository config missing repo' if (!repo_config[:repo] || repo_config[:repo].nil?)

        repo_config[:branch] ||= 'master'

        register_web_hook(repo_config)

        overlay_repo repo_config
      end
    end

    # Register our listener on the repo
    #
    def self.register_web_hook repo_config
      # Make sure our routes are loaded
      Rails.application.reload_routes!

      # Build hook url
      host = config.host_name || ENV['SERVER_HOST_NAME'] || Socket.gethostname
      port = config.host_port || ENV['SERVER_HOST_PORT'] || Rails::Server.new.options[:Port]
      path = Overlay::Engine.routes.url_for({:controller=>"overlay/github", :action=>"update", :only_path => true})
      uri  = ActionDispatch::Http::URL::url_for({:host => host, :port => port, :path => "#{config.relative_root_url}#{path}"})

      # Retrieve current web hooks
      current_hooks = github_repo.hooks.list(repo_config[:user], repo_config[:repo]).response.body
      if current_hooks.find {|hook| hook.config.url == uri}.nil?
        # register hook
        github_repo.hooks.create(repo_config[:user], repo_config[:repo], name: 'web', active: true, config: {:url => uri, :content_type => 'json'})
      end
    end

    def self.overlay_repo repo_config
      Thread.new do
        Rails.logger.info "Start processing repo with config #{repo_config.inspect}"
        # Get our root entries
        #
        root = repo_config[:root_source_path] || '/'

        # If we have a root defined, jump right into it
        #
        if (root != '/')
          overlay_directory(root, repo_config)
        else
          root_entries = github_repo.contents.get(repo_config[:user], repo_config[:repo], root, ref: repo_config[:branch]).response.body

          # We aren't pulling anything out of root.  Cycle through directories and overlay
          #
          root_entries.each do |entry|
            if entry.type == 'dir'
              overlay_directory(entry.path, repo_config)
            end
          end
        end
        Rails.logger.info "Finished processing repo with config #{repo_config.inspect}"
      end
    end

    def self.overlay_directory path, repo_config
      root_path = repo_config[:root_dest_path].empty? ? "#{Rails.application.root}" : "#{Rails.application.root}/#{repo_config[:root_dest_path]}"
      dynamic_path = path.partition(repo_config[:root_source_path]).last

      FileUtils.mkdir_p "#{root_path}/#{dynamic_path}"
      directory_entries = github_repo.contents.get(repo_config[:user], repo_config[:repo], path, ref: repo_config[:branch]).response.body

      directory_entries.each do |entry|
        if entry.type == 'dir'
          overlay_directory(entry.path, repo_config)
        elsif entry.type == 'file'
          clone_file(entry.path, repo_config)
        end
      end
    end

    def self.clone_file path, repo_config
      root_path = repo_config[:root_dest_path].empty? ? "#{Rails.application.root}" : "#{Rails.application.root}/#{repo_config[:root_dest_path]}"
      dynamic_path = path.partition(repo_config[:root_source_path]).last

      file = github_repo.contents.get(repo_config[:user], repo_config[:repo], path, ref: repo_config[:branch]).response.body.content
      File.open("#{root_path}/#{dynamic_path}", "wb") { |f| f.write(Base64.decode64(file)) }
    end

    private

    def self.github_repo
      @@github ||= ::Github::Repos.new
    end

    def self.config
      @@overlay_config ||= Overlay.configuration
    end

    # Configure the github api
    def self.configure
      # Validate required config
      raise 'Configuration github_overlays.basic_auth not set' if (!config.auth || config.auth.nil?)

      ::Github.configure do |github_config|
        github_config.endpoint    = config.endpoint if config.endpoint
        github_config.site        = config.site if config.site
        github_config.basic_auth  = config.auth
        github_config.adapter     = :net_http
        github_config.ssl         = {:verify => false}
      end
    end
  end
end