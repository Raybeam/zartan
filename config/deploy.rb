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

  desc "Generate the resque_pool config file"
  after :finished, :build_pool do
    on roles(:web) do
      within release_path do
        with rails_env: :production do
          rake 'config:pool'
        end
      end
    end
  end
  
  desc "Set default values for global parameters in redis"
  after :build_pool, :seed_config do
    on roles(:web) do
      within release_path do
        with rails_env: :production do
          rake 'config:seed'
        end
      end
    end
  end
  
  desc "Restart zartan-related monitored processes"
  after :seed_config, :restart do
    on roles(:web) do
      if test("ps cax | grep monit")
        execute :sudo, *%w(monit -g zartan_app restart all)
      else
        info "monit is not running, so we can't safely restart Zartan"
      end
    end
  end

end
