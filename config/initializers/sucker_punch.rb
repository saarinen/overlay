require 'sucker_punch'

SuckerPunch.config do
  queue name: :github_queue, worker: Overlay::GithubJob, workers: 5
end