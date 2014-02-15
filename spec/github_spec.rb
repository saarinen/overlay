require 'spec_helper'

describe Overlay::Github do
  describe "process overlays" do
    before :each do
      # Configure the overlay
      Overlay.configuration.reset if Overlay.configuration

      Overlay.configure do |config|
        config.repositories << Overlay::GithubRepo.new(
            'https://api.github.com',
            'http://github.com',
            'test_org',
            'test_repo',
            'test_user:test_pass',
            'spec',
            'spec'
          )

        # Configure host port as Rails::Server is not available
        #
        config.host_port = 3000
      end
    end

    it "should configure the github_api" do
      Overlay::Github.instance.stub(:register_web_hook).and_return
      Overlay::Github.instance.stub(:overlay_repo).and_return

      Overlay::Github.instance.should_receive(:github_repo).once
      Overlay::Github.instance.process_overlays
    end

    it "should verify the user and repo config" do
      Overlay::Github.instance.stub(:register_web_hook).and_return
      Overlay::Github.instance.stub(:overlay_repo).and_return

      Overlay.configuration.repositories.first.org = nil

      expect{Overlay::Github.instance.process_overlays}.to raise_error("Respository config missing org")

      Overlay.configuration.repositories.first.org = 'test'
      Overlay.configuration.repositories.first.repo = nil

      expect{Overlay::Github.instance.process_overlays}.to raise_error("Respository config missing repo")
    end

    it "should call to add a web_hook" do
      Overlay::Github.instance.stub(:overlay_repo).and_return

      Overlay::Github.instance.should_receive(:register_web_hook).once.and_return
      Overlay::Github.instance.process_overlays
    end

    it "should overlay the repo" do
      Overlay::Github.instance.stub(:register_web_hook).and_return

      Overlay::Github.instance.should_receive(:overlay_repo).once.and_return
      Overlay::Github.instance.process_overlays
    end
  end

  describe "configure github_api" do
    before :each do
      # Configure the overlay
      Overlay.configuration.reset if Overlay.configuration

      Overlay.configure do |config|
        config.repositories << Overlay::GithubRepo.new(
            'https://api.github.com',
            'http://github.com',
            'test_org',
            'test_repo',
            'test_user:test_pass',
            'spec',
            'spec'
          )

        # Configure host port as Rails::Server is not available
        #
        config.host_port = 3000
      end
    end

    it "should verify basic auth" do
      Overlay.configuration.reset

      Overlay.configuration.repositories << Overlay::GithubRepo.new(
            'https://api.github.com',
            'http://github.com',
            'test',
            'test',
            nil,
            'spec',
            'spec'
          )

      expect{Overlay::Github.instance.process_overlays}.to raise_error("Respository config auth not set")
    end
  end

  describe 'overlay_publisher integration' do
    before :each do
      # Configure the overlay
      Overlay.configuration.reset if Overlay.configuration
      repo_config = Overlay::GithubRepo.new(
            'https://api.github.com',
            'http://github.com',
            'test_org',
            'test_repo',
            'test_user:test_pass',
            'spec',
            'spec'
          )
      repo_config.use_publisher         = true
      repo_config.redis_server          = 'localhost'
      repo_config.redis_port            = 6379
      repo_config.registration_address  = 'http://localhost:4567'

      Overlay.configure do |config|
        config.repositories << repo_config
        config.host_port = 3000
      end

      stub_request(:post, /localhost:4567/).
        with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: "{\"publish_key\": \"overlay_publisher_test_org_test_repo\"}", headers: {})
    end

    it 'should validate registration_address' do
      Overlay.configuration.repositories.first.registration_address = nil
      expect{Overlay::Github.instance.process_overlays}.to raise_error("Publisher registration_address not set")
    end

    it 'should validate redis server' do
      Overlay.configuration.repositories.first.redis_server = nil
      expect{Overlay::Github.instance.process_overlays}.to raise_error("Publisher redis_server not set")
    end

    it 'should validate redis port' do
      Overlay.configuration.repositories.first.redis_port = nil
      expect{Overlay::Github.instance.process_overlays}.to raise_error("Publisher redis_port not set")
    end

    it 'should call publisher_subscribe if publisher enabled' do
      Overlay::Github.instance.should_receive(:overlay_repo).once.and_return
      Overlay::Github.instance.should_receive(:publisher_subscribe).once.and_return
      Overlay::Github.instance.process_overlays
    end

    it 'should register with the OverlayPublisher' do
      Overlay::Github.instance.should_receive(:overlay_repo).once.and_return
      Overlay::Github.instance.should_receive(:subscribe_to_channel).once.with('overlay_publisher_test_org_test_repo',Overlay.configuration.repositories.first).and_return
      Overlay::Github.instance.process_overlays
    end
  end
end
