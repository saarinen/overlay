module Overlay
  class GithubController < Overlay::ApplicationController
    def update
      render nothing: true

      Overlay.configuration.repositories.each do |repo_config|
        next unless repo_config.class == GithubRepo
        branch = repo_config.branch

        if (params[:repository] && params[:ref])
          if (params[:repository][:name] == repo_config.repo) && (params[:ref] == "refs/heads/#{branch}")
            Overlay::Github.instance.process_hook(params, repo_config)
          end
        end
      end
    end
  end
end
