module Overlay
  class Engine < ::Rails::Engine
    isolate_namespace Overlay

    config.after_initialize do
      ActionController::Base.class_eval do
        before_filter do
          Overlay.configuration.repositories.each do |repo_config|
            prepend_view_path repo_config[:root_dest_path]
          end
        end
      end
    end
  end
end
