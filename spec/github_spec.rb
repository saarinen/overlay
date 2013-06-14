require 'spec_helper'

describe Overlay::Github do
  before :each do
    # Configure the overlay
    Overlay.configuration.reset if Overlay.configuration

    Overlay.configure do |config|
      config.auth = 'test_user:test_password'
      config.repositories << Overlay::GithubRepo.new('saarinen', 'overlay', 'master', 'spec', 'spec')

      # Configure host port as Rails::Server is not available
      #
      config.host_port = 3000
    end
  end

  describe "process overlays" do
    it "should configure the github_api" do
      Overlay::Github.stub(:register_web_hook).and_return
      Overlay::Github.stub(:overlay_repo).and_return

      Overlay::Github.should_receive(:configure).once
      Overlay::Github.process_overlays
    end

    it "should verify the user and repo config" do
      Overlay::Github.stub(:register_web_hook).and_return
      Overlay::Github.stub(:overlay_repo).and_return

      Overlay.configuration.repositories << Overlay::GithubRepo.new(nil, nil, 'master', 'spec', 'spec')

      expect{Overlay::Github.process_overlays}.to raise_error("Respository config missing user")

      Overlay.configuration.reset

      Overlay.configuration.repositories << Overlay::GithubRepo.new("test", nil, 'master', 'spec', 'spec')

      expect{Overlay::Github.process_overlays}.to raise_error("Respository config missing repo")
    end

    it "should call to add a web_hook" do
      Overlay::Github.stub(:overlay_repo).and_return

      Overlay::Github.should_receive(:register_web_hook).once.and_return
      Overlay::Github.process_overlays
    end

    it "should overlay the repo" do
      Overlay::Github.stub(:register_web_hook).and_return

      Overlay::Github.should_receive(:overlay_repo).once.and_return
      Overlay::Github.process_overlays
    end
  end

  describe "configure github_api" do
    it "should call github api configure" do
      ::Github.should_receive(:configure).once
      Overlay::Github.configure
    end

    it "should set a custom site address" do
      Overlay.configuration.site = "http://www.example.com"
      Overlay::Github.configure
      expect(::Github::Repos.new.site).to eq("http://www.example.com")
    end

    it "should verify basic auth" do
      Overlay.configuration.auth = nil
      expect{Overlay::Github.configure}.to raise_error("Configuration github_overlays.basic_auth not set")
    end

    it "should set auth" do
      Overlay::Github.configure
      expect(::Github::Repos.new.basic_auth).to eq('test_user:test_password')
    end
  end

  describe "overlay_repo" do
    it "should jump directly to overlay_directory if root set" do
      repo_config = Overlay::GithubRepo.new('saarinen', 'overlay', 'master', 'spec', 'spec')
      Overlay::Github.should_receive(:overlay_directory).once.with('spec', repo_config).and_return
      Overlay::Github.overlay_repo repo_config
    end

    it "should ignore any files in repo root"

    it "should process all directories in repo root"
  end

  describe "overlay_directory" do
    it "should set path correctly based on root"
    it "should create path for directory"
    it "should call clone_files for all files in directory"
    it "should call overlay_directory for all directories"
  end

  describe "clone_file" do
    it "should create a file for the cloned file"
    it "should corrctly set the file path"
  end
end
