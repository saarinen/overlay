require 'spec_helper'
require 'socket'

describe Overlay::Github do

  let(:repo_config) do
    Overlay::GithubRepo.new({
      org: 'test_org',
      repo: 'test_repo',
      auth: 'test_user:test_pass',
      root_source_path: 'spec',
      root_dest_path: 'spec'
    })
  end

  describe "Register Github webhook" do
    before :each do
      # Configure the overlay
      Overlay.configuration.reset if Overlay.configuration

      Overlay.configure do |config|
        # Configure host port as Rails::Server is not available
        config.host_port = 3000
      end


      Overlay.configuration.repositories = Set.new [repo_config]
    end

    it 'should register a webhook with github' do
      config = Overlay.configuration.repositories.first
      allow(Overlay::Github.instance).to receive(:fork_it).with(:overlay_repo, config).and_return

      stub_request(:get, /api.github.com/).
        with(:headers => {'Accept'=>'application/vnd.github.v3+json,application/vnd.github.beta+json;q=0.5,application/json;q=0.1', 'Accept-Charset'=>'utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Github Ruby Gem 0.11.2'}).
        to_return(:status => 200, :body => '[]', :headers => {})

      expect(repo_config.github_api.hooks).to receive(:create).with(
        'test_org',
        'test_repo',
        name: 'web',
        active: true,
        config: {:url => "http://#{Socket.gethostname}:3000/overlay/github/update", :content_type => 'json'}
        ).and_return

      Overlay::Github.instance.process_overlays
    end

    it 'should use a configured endpoint' do
      config = Overlay.configuration.repositories.first
      config.endpoint = "https://www.test.com"

      allow(Overlay::Github.instance).to receive(:fork_it).with(:overlay_repo, config).and_return

      stub_request(:get, /www.test.com/).
        with(:headers => {'Accept'=>'application/vnd.github.v3+json,application/vnd.github.beta+json;q=0.5,application/json;q=0.1', 'Accept-Charset'=>'utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Github Ruby Gem 0.11.2'}).
        to_return(:status => 200, :body => '[]', :headers => {})

      expect(repo_config.github_api.hooks).to receive(:create).with(
        'test_org',
        'test_repo',
        name: 'web',
        active: true,
        config: {:url => "http://#{Socket.gethostname}:3000/overlay/github/update", :content_type => 'json'}
        ).and_return

      Overlay::Github.instance.process_overlays
    end
  end

  describe 'initial overlay_repo' do
    it 'should retry overlay_repo until completion' do
      @times_called = 0
      allow(Overlay::Github.instance).to receive(:sleep).and_return
      expect(Overlay::Github.instance).to receive(:overlay_directory).exactly(5).times.and_return do
        @times_called += 1
        raise StandardError unless @times_called == 5
      end
      Overlay::Github.instance.send(:overlay_repo, repo_config)
    end
  end

  describe 'subscribe to a redis publisher' do
    before :each do
      # Configure the overlay
      Overlay.configuration.reset if Overlay.configuration

      Overlay.configure do |config|
        # Configure host port as Rails::Server is not available
        config.host_port = 3000
      end

      config = repo_config
      config.use_publisher        = true
      config.redis_server         = 'unreachable'
      config.redis_port           = 6734
      config.registration_server  = "http://www.test.com"

      Overlay.configuration.repositories = Set.new [config]
    end

    it 'should call publisher_subscribe' do
      config = Overlay.configuration.repositories.first
      allow(Overlay::Github.instance).to receive(:fork_it).with(:overlay_repo, config).and_return

      expect(Overlay::Github.instance).to receive(:publisher_subscribe).with(config).and_return

      Overlay::Github.instance.process_overlays
    end

    it 'should send a registration request' do
      config = Overlay.configuration.repositories.first
      allow(Overlay::Github.instance).to receive(:fork_it).with(:overlay_repo, config).and_return
      expect(Overlay::Github.instance).to receive(:fork_it).with(:subscribe_to_channel, "test_key", config).and_return

      stub_request(:post, /www.test.com/).
        with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: "{\"publish_key\": \"test_key\"}", headers: {})

      Overlay::Github.instance.process_overlays
    end

    it 'should retry on error' do
      allow(Overlay::Github.instance).to receive(:sleep).and_return
      @times_called = 0
      redis = double("Redis")
      Redis.stub(:new).and_return(redis)
      redis.stub(:subscribe).and_return do
        @times_called += 1
        raise StandardError unless @times_called == 5
      end
      expect(redis).to receive(:subscribe).exactly(5).times
      Overlay::Github.instance.send(:subscribe_to_channel, "test", Overlay.configuration.repositories.first)
    end
  end

  describe 'process webhook payload' do
    let(:repo_config) do
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: 'test_repo',
        auth: 'test_user:test_pass',
        root_source_path: 'lib',
        root_dest_path: 'lib'
      })
    end

    let(:payload) do
      JSON.parse(
        "{
          \"ref\":\"refs/heads/master\",
          \"after\":\"3524f66a6b374a35a5359905be8a87a3931eba17\",
          \"before\":\"57f73e81329ef71a37c55c2f41b48910f9a7c790\",
          \"created\":false,
          \"deleted\":false,
          \"forced\":false,
          \"compare\":\"https://api.test.com/test_org/test_repo/compare/57f73e81329e...3524f66a6b37\",
          \"commits\":[
            {
              \"id\":\"3524f66a6b374a35a5359905be8a87a3931eba17\",
              \"distinct\":true,
              \"message\":\"test webhook\",
              \"timestamp\":\"2014-02-14T22:05:33+00:00\",
              \"url\":\"https://api.test.com/test_org/test_repo/commit/3524f66a6b374a35a5359905be8a87a3931eba17\",
              \"author\":{
                \"name\":\"Steve Saarinen\",
                \"email\":\"ssaarinen@whitepages.com\",
                \"username\":\"saarinen\"
              },
              \"committer\":{
                \"name\":\"Steve Saarinen\",
                \"email\":\"ssaarinen@whitepages.com\",
                \"username\":\"saarinen\"
              },
              \"added\":[
                \"lib/test/test_added.rb\"
              ],
              \"removed\":[
                \"lib/test/test_removed.rb\"
              ],
              \"modified\":[
                \"lib/test/test_modified.rb\"
              ]
            }
          ],
          \"head_commit\":{
            \"id\":\"3524f66a6b374a35a5359905be8a87a3931eba17\",
            \"distinct\":true,
            \"message\":\"test webhook\",
            \"timestamp\":\"2014-02-14T22:05:33+00:00\",
            \"url\":\"https://api.test.com/test_org/test_repo/commit/3524f66a6b374a35a5359905be8a87a3931eba17\",
            \"author\":{
              \"name\":\"Steve Saarinen\",
              \"email\":\"ssaarinen@whitepages.com\",
              \"username\":\"saarinen\"
            },
            \"committer\":{
              \"name\":\"Steve Saarinen\",
              \"email\":\"ssaarinen@whitepages.com\",
              \"username\":\"saarinen\"
            },
            \"added\":[
              \"lib/test/test_added.rb\"
            ],
            \"removed\":[
              \"lib/test/test_removed.rb\"
            ],
            \"modified\":[
              \"lib/test/test_modified.rb\"
            ]
          },
          \"repository\":{
            \"id\":1720,
            \"name\":\"bing_maps\",
            \"url\":\"https://www.test.com/test_org/test_repo\",
            \"description\":\"Gem providing Bing Maps API integration\",
            \"watchers\":0,
            \"stargazers\":0,
            \"forks\":0,
            \"fork\":true,
            \"size\":412,
            \"owner\":{
              \"name\":\"saarinen\",
              \"email\":\"ssaarinen@whitepages.com\"
            },
            \"private\":false,
            \"open_issues\":0,
            \"has_issues\":false,
            \"has_downloads\":true,
            \"has_wiki\":true,
            \"language\":\"Ruby\",
            \"created_at\":1383860934,
            \"pushed_at\":1392415533,
            \"master_branch\":\"master\"
          },
          \"pusher\":{
            \"name\":\"saarinen\",
            \"email\":\"ssaarinen@whitepages.com\"
          }
        }"
      )
    end

    it 'should make a directory for a new file' do
      allow(Overlay::Github.instance).to receive(:clone_file).and_return
      allow(File).to receive(:delete).and_return
      expect(FileUtils).to receive(:mkdir_p).with("#{Rails.application.root}/lib/test")

      Overlay::Github.instance.process_hook(payload, repo_config)
    end

    it 'should remove a deleted file' do
      allow(Overlay::Github.instance).to receive(:clone_file).and_return
      allow(FileUtils).to receive(:mkdir_p).and_return
      expect(File).to receive(:delete).with("#{Rails.application.root}/lib/test/test_removed.rb").and_return

      Overlay::Github.instance.process_hook(payload, repo_config)
    end

    it 'should clone added or modified files' do
      allow(FileUtils).to receive(:mkdir_p).and_return
      allow(File).to receive(:delete).and_return
      expect(Overlay::Github.instance).to receive(:clone_file).with("lib/test/test_added.rb", repo_config).and_return
      expect(Overlay::Github.instance).to receive(:clone_file).with("lib/test/test_modified.rb", repo_config).and_return

      Overlay::Github.instance.process_hook(payload, repo_config)
    end

    it 'should call post_hook after hook is processed' do
      allow(FileUtils).to receive(:mkdir_p).and_return
      allow(File).to receive(:delete).and_return
      allow(Overlay::Github.instance).to receive(:clone_file).and_return

      hook_ran = false

      repo_config.after_process_hook do
        hook_ran = true
      end

      Overlay::Github.instance.process_hook(payload, repo_config)

      expect(hook_ran).to eq(true)
    end

    it 'should process hook with null added descriptors' do
      allow(FileUtils).to receive(:mkdir_p).and_return
      allow(File).to receive(:delete).and_return
      allow(Overlay::Github.instance).to receive(:clone_file).and_return

      # Remove added file
      payload_modified = payload
      payload_modified['commits'].first['added'] = nil

      expect { Overlay::Github.instance.process_hook(payload_modified, repo_config) }.to_not raise_error
    end

    it 'should process hook with null modified descriptors' do
      allow(FileUtils).to receive(:mkdir_p).and_return
      allow(File).to receive(:delete).and_return
      allow(Overlay::Github.instance).to receive(:clone_file).and_return

      # Remove modified file
      payload_modified = payload
      payload_modified['commits'].first['modified'] = nil

      expect { Overlay::Github.instance.process_hook(payload_modified, repo_config) }.to_not raise_error
    end

    it 'should process hook with null removed descriptors' do
      allow(FileUtils).to receive(:mkdir_p).and_return
      allow(File).to receive(:delete).and_return
      allow(Overlay::Github.instance).to receive(:clone_file).and_return

      # Remove removed file
      payload_modified = payload
      payload_modified['commits'].first['removed'] = nil

      expect { Overlay::Github.instance.process_hook(payload_modified, repo_config) }.to_not raise_error
    end
  end
end
