require_dependency "overlay/application_controller"

module Overlay
  class GithubController < ApplicationController
    def update
      render nothing: true

      Overlay.configuration.repositories.each do |repo_config|
        next unless repo_config.class == GithubRepo
        branch = repo_config[:branch] || 'master'
        if (params[:repository] && params[:ref])
          if (params[:repository][:name] == repo_config[:repo]) && (params[:ref] == "refs/heads/#{branch}")
            Overlay::GithubJob.new.async.perform repo_config
          end
        end
      end
    end
  end
end
