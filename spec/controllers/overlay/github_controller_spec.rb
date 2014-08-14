require 'spec_helper'

module Overlay
  describe GithubController do
    include RSpec::Rails::ControllerExampleGroup
    before :each do
      Overlay.configuration.reset if Overlay.configuration

      Overlay.configure do |config|
        config.repositories << Overlay::GithubRepo.new({
                                org: 'test_org',
                                repo: 'test_repo',
                                auth: 'test_user:test_pass',
                                root_source_path: 'spec',
                                root_dest_path: 'spec'
                              })
      end
    end

    describe "POST 'update'" do
      it "returns http success" do
        expect(Overlay::Github.instance).to receive(:process_hook).once {true}
        post 'update', {:use_route => :overlay, :ref => "refs/heads/master", :repository => {:name => 'test_repo'}}
      end
    end
  end
end
