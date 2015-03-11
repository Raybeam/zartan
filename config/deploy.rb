# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'zartan'

set :scm, :git
set :repo_url, 'git@github.com:Raybeam/zartan.git'
set :branch, 'master'

set :deploy_to, '/var/www/zartan'
set :default_env, { rvm_bin_path: '~/.rvm/bin' }

set :linked_files, %w{
  config/database.yml
  config/redis.yml
  config/secrets.yml
}


namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
