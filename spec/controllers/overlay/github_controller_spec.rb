require 'spec_helper'

module Overlay
  describe GithubController do
    before :each do
      Overlay.configuration.reset if Overlay.configuration

      Overlay.configure do |config|
        config.repositories << Overlay::GithubRepo.new(
            'https://api.github.com',
            'http://github.com',
            'test',
            'test',
            'test_user:test_pass',
            'spec',
            'spec'
          )
      end
    end

    describe "POST 'update'" do
      it "returns http success" do
        Overlay::Github.instance.should_receive(:process_hook).once
        post 'update', {:use_route => :overlay, :ref => "refs/heads/master", :repository => {:name => 'test'}}
      end
    end
  end
end
