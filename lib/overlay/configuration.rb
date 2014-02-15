
module Overlay
  VALID_OPTIONS_KEYS = [
    :repositories,
    :host_name,
    :host_port,
    :relative_root_url
  ].freeze

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
  # :endpoint,
  # :site,
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
  class GithubRepo
    attr_accessor :endpoint, :site, :org, :repo, :auth, :root_source_path, :root_dest_path
    attr_accessor :use_publisher, :redis_server, :redis_port, :registration_address, :branch

    # Internal repo api hook
    attr_accessor :github_repo

    def initialize(endpoint, site, org, repo, auth, root_source_path, root_dest_path)
      @endpoint         = endpoint
      @site             = site
      @org              = org
      @repo             = repo
      @auth             = auth
      @root_source_path = root_source_path
      @root_dest_path   = root_dest_path
      @branch           = 'master'
      @use_publisher    = false
    end
  end
end