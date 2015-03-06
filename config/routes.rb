Rails.application.routes.draw do
  # API Routes
  # The constraint is necessary to ensure that :site_name can contain dots
  constraints site_name: %r{[a-z0-9_.-]+} do
    get  'v1/:site_name',                     to: 'api/version1#get_proxy'
    post 'v1/:site_name/:proxy_id/succeeded', to: 'api/version1#report_result', succeeded: true
    post 'v1/:site_name/:proxy_id/failed',    to: 'api/version1#report_result', succeeded: false
  end
  
  # Admin UI Routes
  resources :sites, only: %i(index show update)
  resources :sources, except: %i(destroy)
  resources :proxies, only: %i(show)
  
  get 'config',      to: 'config#show', as: :config
  post 'config/set', to: 'config#set', as: :config_set
  
  # Map / to the sites page
  root to: 'sites#index'
end
