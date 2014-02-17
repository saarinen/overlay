require 'spec_helper'

# Test our configuration objects
describe Overlay::GithubRepo do

  let(:repo_config) do
    Overlay::GithubRepo.new('org', 'repo', 'auth', 'test', '/')
  end

  it "should allow basic creation" do
    expect {
      test = Overlay::GithubRepo.new('org', 'repo', 'auth', 'test', '/')
    }.to_not raise_error
  end

  it 'should throw error for missing org' do
    expect {
      test = Overlay::GithubRepo.new('', 'repo', 'auth', 'test', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: org")

    expect {
      test = Overlay::GithubRepo.new(nil, 'repo', 'auth', 'test', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: org")
  end

  it 'should throw error for missing repo' do
    expect {
      test = Overlay::GithubRepo.new('org', '', 'auth', 'test', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: repo")

    expect {
      test = Overlay::GithubRepo.new('org', nil, 'auth', 'test', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: repo")
  end

  it 'should throw error for missing auth' do
    expect {
      test = Overlay::GithubRepo.new('org', 'repo', '', 'test', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: auth")

    expect {
      test = Overlay::GithubRepo.new('org', 'repo', nil, 'test', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: auth")
  end

  it 'should throw error for missing source root_source_path' do
    expect {
      test = Overlay::GithubRepo.new('org', 'repo', 'auth', '', '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: root_source_path")

    expect {
      test = Overlay::GithubRepo.new('org', 'repo', 'auth', nil, '/')
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: root_source_path")
  end

  describe 'OverlayPublisher configuration' do

    it 'should validate successfully for correct publisher params' do
      repo_config.use_publisher         = true
      repo_config.redis_server          = 'localhost'
      repo_config.redis_port            = 4567
      repo_config.registration_server   = 'http://localhost:4567'

      expect { repo_config.validate }.to_not raise_error
    end

    it 'should validate redis_server' do
      repo_config.use_publisher         = true
      repo_config.redis_port            = 4567
      repo_config.registration_server   = 'http://localhost:4567'

      expect { repo_config.validate }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: redis_server")
    end

    it 'should validate redis_port' do
      repo_config.use_publisher         = true
      repo_config.redis_server          = 'localhost'
      repo_config.registration_server   = 'http://localhost:4567'

      expect { repo_config.validate }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: redis_port")
    end

    it 'should validate registration_server' do
      repo_config.use_publisher         = true
      repo_config.redis_server          = 'localhost'
      repo_config.redis_port            = 4567

      expect { repo_config.validate }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: registration_server")
    end
  end

  describe 'GithubRepo api initialization' do

    it 'should initialize the API with correct settings' do
      github_api = repo_config.github_api

      expect(github_api.current_options[:org]) .to eq('org')
      expect(github_api.current_options[:repo]) .to eq('repo')
      expect(github_api.current_options[:login]) .to eq('auth')
    end

    it 'should reinitialize api when endpoint is changed' do
      repo_config.endpoint = "http://api.test.com"
      expect(repo_config.github_api.current_options[:endpoint]).to eq('http://api.test.com')
    end

    it 'should reinitialize api when site is changed' do
      repo_config.site = "http://www.test.com"
      expect(repo_config.github_api.current_options[:site]).to eq('http://www.test.com')
    end
  end

  describe 'GithubRepo read only properties' do

    it 'should not allow me to reset repo' do
      expect { repo_config.repo = 'repo2'}.to raise_error
    end

    it 'should not allow me to reset org' do
      expect { repo_config.org = 'org2'}.to raise_error
    end

    it 'should not allow me to reset auth' do
      expect { repo_config.auth = 'auth2'}.to raise_error
    end
  end

  describe 'GithubRepo post_hook operation' do
    it 'should require a block' do
      expect{ repo_config.after_process_hook }.to raise_error(ArgumentError)
    end

    it 'should run the code provided when calling post_hook' do
      hook_ran = false

      repo_config.after_process_hook do
        hook_ran = true
      end

      repo_config.post_hook

      expect(hook_ran).to eq(true)
    end
  end
end