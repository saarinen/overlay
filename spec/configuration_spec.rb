require 'spec_helper'

# Test our configuration objects
describe Overlay::GithubRepo do

  let(:repo_config) do
    Overlay::GithubRepo.new({
      org: 'test_org',
      repo: 'test_repo',
      auth: 'test_user:test_pass',
      root_source_path: 'test',
      root_dest_path: '/'
    })
  end

  it "should allow basic creation" do
    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: 'test_repo',
        auth: 'test_user:test_pass',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to_not raise_error
  end

  it 'should throw error for missing org' do
    expect {
      Overlay::GithubRepo.new({
        org: '',
        repo: 'test_repo',
        auth: 'test_user:test_pass',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: org")

    expect {
      Overlay::GithubRepo.new({        repo: 'test_repo',
        auth: 'test_user:test_pass',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: org")
  end

  it 'should throw error for missing repo' do
    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: '',
        auth: 'test_user:test_pass',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: repo")

    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        auth: 'test_user:test_pass',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: repo")
  end

  it 'should throw error for missing auth' do
    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: 'test_repo',
        auth: '',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: auth")

    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: 'test_repo',
        root_source_path: 'test',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: auth")
  end

  it 'should throw error for missing source root_source_path' do
    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: 'test_repo',
        auth: 'test_user:test_pass',
        root_source_path: '',
        root_dest_path: '/'
      })
    }.to raise_error(Overlay::RequiredParameterError, "Overlay GithubRepo missing required paramater: root_source_path")

    expect {
      Overlay::GithubRepo.new({
        org: 'test_org',
        repo: 'test_repo',
        auth: 'test_user:test_pass',
        root_dest_path: '/'
      })
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

      expect(github_api.current_options[:org]) .to eq('test_org')
      expect(github_api.current_options[:repo]) .to eq('test_repo')
      expect(github_api.current_options[:login]) .to eq('test_user')
      expect(github_api.current_options[:password]) .to eq('test_pass')
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