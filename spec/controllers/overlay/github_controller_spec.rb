require 'spec_helper'

module Overlay
  describe GithubController do

    describe "GET 'update'" do
      it "returns http success" do
        get 'update'
        response.should be_success
      end
    end

  end
end
