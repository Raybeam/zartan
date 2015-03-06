Rails.application.routes.draw do
  get  'v1/:site_name',                     to: 'api/version1#get_proxy', defaults: { older_than: -1 }
  post 'v1/:site_name/:proxy_id/succeeded', to: 'api/version1#report_result', succeeded: true
  post 'v1/:site_name/:proxy_id/failed',    to: 'api/version1#report_result', succeeded: false
  
  resources :sites, only: %i(index show update)
  resources :sources, except: %i(destroy)
  resources :proxies, only: %i(show)
  
  get 'config',      to: 'config#show', as: :config
  post 'config/set', to: 'config#set', as: :config_set
  
  root to: 'sites#index'
end
