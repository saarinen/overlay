module Overlay
  VALID_OPTIONS_KEYS = [
    :site,
    :endpoint,
    :repo,
    :user,
    :auth,
    :repositories,
    :hostname,
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
       @site = 'https://github.com'
       @endpoint = 'https://api.github.com'
       @repositories = Set.new
    end
  end

  GithubRepo = Struct.new(:user, :repo, :branch, :root_path)
end