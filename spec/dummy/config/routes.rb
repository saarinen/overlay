Rails.application.routes.draw do

  mount Overlay::Engine => "/overlay"
end
