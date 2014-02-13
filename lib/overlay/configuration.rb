module Overlay

  class PostHookExists < StandardError; end

  VALID_OPTIONS_KEYS = [
    :site,
    :endpoint,
    :repo,
    :user,
    :auth,
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
       @site = 'https://github.com'
       @endpoint = 'https://api.github.com'
       @repositories = Set.new
    end

    def after_overlay(&hook)
      raise ArgumentError, "No block given" unless block_given?
      raise Overlay::PostHookExists, "Overlay post hook already set" unless @post_hook.nil?
      @post_hook = hook 
    end

    def post_hook
      @post_hook.call if !@post_hook.nil?
    end

  end

  GithubRepo = Struct.new(:user, :repo, :branch, :root_source_path, :root_dest_path)
end
