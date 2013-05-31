require 'github_api'
require 'fileutils'
require 'socket'

module Overlay
  class Github
    include Overlay::Engine.routes.url_helpers
    # Cycle through all configured repositories and overlay
    #
    def self.process_overlays
      # If we aren't running in Rails, bail out.  This may be some
      # other request such as rake routes loading the environment
      #
      return unless defined?(Rails::Server)

      # Configure github api
      configure

      Overlay.configuration.repositories.each do |repo_config|
        next unless repo_config.class == GithubRepo

        # Validate repository config
        raise 'Respository config missing user' if (!repo_config[:user] || repo_config[:user].nil?)
        raise 'Respository config missing repo' if (!repo_config[:repo] || repo_config[:repo].nil?)

        branch = repo_config[:branch] || 'master'

        register_web_hook(repo_config[:user], repo_config[:repo])

        overlay_repo(repo_config[:user], repo_config[:repo], branch)
      end
    end

    # Register our listener on the repo
    #
    def self.register_web_hook user, repo
      # Make sure our routes are loaded
      Rails.application.reload_routes!

      # Build hook url
      host = Overlay.configuration.hostname || Socket.gethostname
      port = Overlay.configuration.host_port || Rails::Server.new.options[:Port]
      uri  = Overlay::Engine.routes.url_for({:controller=>"github_overlays/webhooks", :action=>"update", :host => host, :port => port})

      # Retrieve current web hooks
      current_hooks = github_repo.hooks.list(user, repo).response.body
      if current_hooks.find {|hook| hook.config.url == uri}.nil?
        #register hook
        github_repo.hooks.create(user, repo, name: 'web', active: true, config: {:url => uri, :content_type => 'json'})
      end
    end

    def self.overlay_repo user, repo, branch
      # Get our root entries
      #
      root_entries = github_repo.contents.get(user, repo, '/', ref: branch).response.body

      # We aren't pulling anything out of root.  Cycle through directories and overlay
      #
      root_entries.each do |entry|
        if entry.type == 'dir'
          overlay_directory(entry.path, user, repo, branch)
        end
      end
    end

    def self.overlay_directory path, user, repo, branch
      FileUtils.mkdir_p "#{Rails.application.root}/#{path}"
      directory_entries = github_repo.contents.get(user, repo, path, ref: branch).response.body

      directory_entries.each do |entry|
        if entry.type == 'dir'
          overlay_directory(entry.path, user, repo, branch)
        elsif entry.type == 'file'
          clone_file(entry.path, user, repo, branch)
        end
      end
    end

    def self.clone_file path, user, repo, branch
      file = github_repo.contents.get(user, repo, path, ref: branch).response.body.content
      File.open("#{Rails.application.root}/#{path}", "wb") { |f| f.write(Base64.decode64(file)) }
    end

    private

    def self.github_repo
      @@github ||= Github::Repos.new
    end

    def self.config
      @@overlay_config ||= Rails.application.config.github_overlays
    end

    # Configure the github api
    def self.configure
      overlay_config = Overlay.configuration

      # Validate required config
      raise 'Configuration github_overlays.basic_auth not set' if (!overlay_config.auth || overlay_config.auth.nil?)

      Github.configure do |github_config|
        github_config.endpoint    = overlay_config.endpoint if overlay_config.endpoint
        github_config.site        = overlay_config.site if overlay_config.site
        github_config.basic_auth  = overlay_config.auth
        github_config.adapter     = :net_http
        github_config.ssl         = {:verify => false}
      end
    end
  end
end