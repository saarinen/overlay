
module Overlay
  VALID_OPTIONS_KEYS = [
    :repositories,
    :host_name,
    :host_port,
    :relative_root_url
  ].freeze

  # Exceptions
  class RequiredParameterError < StandardError; end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor *VALID_OPTIONS_KEYS

    def initialize
      reset
    end

    def reset
      @repositories = Set.new
    end
  end

  # Configure a github repository.  Required parameters:
  # :org,
  # :repo,
  # :auth,
  # :root_source_path,
  # :root_dest_path

  # Optional parameters:
  # :branch,
  # :use_publisher
  # :registration_address
  # :redis_server
  # :redis_port
  # :endpoint,
  # :site,
  class GithubRepo
    attr_accessor :root_source_path, :root_dest_path, :branch
    attr_accessor :use_publisher, :redis_server, :redis_port, :registration_server
    attr_reader   :repo, :org, :auth, :endpoint, :site

    # Internal repo api hook
    attr_accessor :github_api

    REQUIRED_PARAMS            = [:org, :repo, :auth, :root_source_path]
    REQUIRED_PUBLISHER_PARAMS  = [:redis_server, :redis_port, :registration_server]

    def initialize(options={})
      @org                  = options[:org]
      @repo                 = options[:repo]
      @auth                 = options[:auth]
      @root_source_path     = options[:root_source_path]
      @root_dest_path       = options[:root_dest_path]
      @redis_server         = options[:redis_server]
      @redis_port           = options[:redis_port]
      @registration_server  = options[:registration_server]
      @endpoint             = options[:endpoint]
      @site                 = options[:site]
      @branch               = options[:branch] || 'master'
      @use_publisher        = options[:use_publisher] || false

      # Quick sanity check
      validate

      # Create a hook to the Github API
      initialize_api
    end

    def endpoint=(endpoint_addr)
      @endpoint = endpoint_addr

      # re-initialize api
      initialize_api
    end

    def site=(site_addr)
      @site = site_addr

      # re-initialize api
      initialize_api
    end

    # Make sure that this configuration has all required parameters
    def validate
      REQUIRED_PARAMS.each do |param|
        raise RequiredParameterError, "Overlay GithubRepo missing required paramater: #{param}" if (send(param).nil? || send(param).empty?)
      end

      # If we are using a publisher, check required publisher params
      if @use_publisher
        REQUIRED_PUBLISHER_PARAMS.each do |param|
          raise RequiredParameterError, "Overlay GithubRepo missing required paramater: #{param}" if (send(param).nil?)
        end
      end
    end

    # Add code to be called after processing a hook
    def after_process_hook(&hook)
      raise ArgumentError, "No block given" unless block_given?
      @post_hook = hook
    end

    # Run post_hook code
    def post_hook
      @post_hook.call unless @post_hook.nil?
    end

    # Retrieve API hook to repo
    def initialize_api
      ::Github.reset!
      ::Github.configure do |github_config|
        github_config.endpoint    = @endpoint if @endpoint
        github_config.site        = @site if @site
        github_config.basic_auth  = @auth
        github_config.repo        = @repo
        github_config.org         = @org
        github_config.adapter     = :net_http
        github_config.ssl         = {:verify => false}
      end

      @github_api = ::Github::Repos.new
    end

  end
end