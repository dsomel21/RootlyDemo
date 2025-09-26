Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Slack integration routes
  namespace :slack do
    # Installation page with "Add to Slack" button
    get "install" => "install#show"

    # OAuth callback for app installation
    get "oauth/callback" => "oauth#callback"

    # Slash commands endpoint
    post "commands" => "commands#receive"

    # Interactive components (modals, buttons, etc.)
    post "interactions" => "interactions#receive"
  end


  # Incidents management
  resources :incidents, only: [ :index, :show ]

  # Slug-based URLs work alongside regular show routes
  get "incidents/:slug", to: "incidents#show"

  # Sidekiq Web UI for monitoring background jobs
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Defines the root path route ("/")
  root "incidents#index"
end
