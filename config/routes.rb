Rails.application.routes.draw do
  get  'v1/:site_name',           to: 'api/version1#get_proxy', defaults: { older_than: -1 }
  post 'v1/:site_name/succeeded', to: 'api/version1#report_result', succeeded: true
  post 'v1/:site_name/failed',    to: 'api/version1#report_result', succeeded: false
end
