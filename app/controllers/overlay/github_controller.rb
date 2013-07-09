require_dependency "overlay/application_controller"

module Overlay
  class GithubController < ApplicationController
    def update
      render nothing: true

      logger.info "Received update post for repo: #{params[:repository]} and ref: #{params[:ref]}"
      Overlay.configuration.repositories.each do |repo_config|
        logger.info "Processing config for repo: #{repo_config[:repo]} and branch: #{repo_config[:branch] || 'master'}"
        next unless repo_config.class == GithubRepo
        branch = repo_config[:branch] || 'master'
        if (params[:repository] && params[:ref])
          if (params[:repository][:name] == repo_config[:repo]) && (params[:ref] == "refs/heads/#{branch}")
            logger.info "Processing overlay for repo: #{repo_config[:repo]} and branch: #{repo_config[:branch] || 'master'}"
            SuckerPunch::Queue[:github_queue].async.perform repo_config
          end
        end
      end
    end
  end
end
