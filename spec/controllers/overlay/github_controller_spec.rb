require 'spec_helper'

module Overlay
  describe GithubController do
    before :each do
      Overlay.configure do |config|
        config.repositories << Overlay::GithubRepo.new('test', 'test', 'master', 'test', 'test')
      end
    end

    describe "POST 'update'" do
      it "returns http success" do
        Overlay::Github.stub(:overlay_repo) { true }
        Overlay::Github.should_receive(:overlay_repo).once
        post 'update', {:use_route => :overlay, :ref => "refs/heads/master", :repository => {:name => 'test'}}
        response.should be_success
      end
    end
  end
end
