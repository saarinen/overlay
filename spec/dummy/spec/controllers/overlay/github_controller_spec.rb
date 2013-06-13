require 'spec_helper'

module Overlay
  describe GithubController do
    before :each do
      Overlay.configure do |config|
      end
    end

    describe "POST 'update'" do
      it "returns http success" do
        post 'update', {:use_route => :overlay}
        response.should be_success
      end
    end

  end
end
