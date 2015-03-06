Rails.application.routes.draw do
  get  'v1/:site_name',                     to: 'api/version1#get_proxy', constraints: { site_name: %r{[a-z0-9_.-]+} }
  post 'v1/:site_name/:proxy_id/succeeded', to: 'api/version1#report_result', constraints: { site_name: %r{[a-z0-9_.-]+} }, succeeded: true
  post 'v1/:site_name/:proxy_id/failed',    to: 'api/version1#report_result', constraints: { site_name: %r{[a-z0-9_.-]+} }, succeeded: false
  
  resources :sites, only: %i(index show update)
  resources :sources, except: %i(destroy)
  resources :proxies, only: %i(show)
  
  get 'config',      to: 'config#show', as: :config
  post 'config/set', to: 'config#set', as: :config_set
  
  root to: 'sites#index'
end
