require "resque_web"
ResqueWeb::Engine.eager_load!

Rails.application.routes.draw do

  # API Routes
  # The constraint is necessary to ensure that :site_name can contain dots
  constraints site_name: %r{[a-z0-9_.-]+} do
    get  'v1/:site_name',                     to: 'api/version1#get_proxy'
    post 'v1/:site_name/:proxy_id/succeeded', to: 'api/version1#report_result', succeeded: true
    post 'v1/:site_name/:proxy_id/failed',    to: 'api/version1#report_result', succeeded: false

    get  'v2/authenticate',                          to: 'api/version2#authenticate'
    get  'v2/proxy_for/:site_name',                  to: 'api/version2#get_proxy'
    post 'v2/report/:site_name/:proxy_id/succeeded', to: 'api/version2#report_result', succeeded: true
    post 'v2/report/:site_name/:proxy_id/failed',    to: 'api/version2#report_result', succeeded: false
  end
  
  # Admin UI Routes
  resources :sites, only: %i(index show update)
  resources :sources, except: %i(destroy) do
    post 'clear_errors', on: :member
  end
  resources :proxies, only: %i(show)
  resources :api_keys
  
  mount ResqueWeb::Engine => "/resque_web"

  get 'config',      to: 'config#show', as: :config
  post 'config/set', to: 'config#set', as: :config_set


  # auth routes
  get '/auth/failure' do
    flash[:notice] = params[:message]
    redirect '/'
  end
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/signout', to: 'sessions#destroy'
  
  
  # Map / to the sites page
  root to: 'home#index'
end
