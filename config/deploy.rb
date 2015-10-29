# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'zartan'

set :scm, :git
set :branch, 'master'

set :deploy_to, '/var/www/zartan'
set :default_env, { rvm_bin_path: '~/.rvm/bin' }

set :linked_files, %w{
  config/database.yml
  config/google_omniauth.yml
  config/redis.yml
  config/resque_schedule.yml
  config/secrets.yml
  config/unicorn.rb
}
set :rails_env, :production
set :log_level, :info


namespace :deploy do

  desc "Generate the resque_pool config file"
  after :finished, :build_pool do
    on roles(:web) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          rake 'config:pool'
        end
      end
    end
  end

  desc "Set default values for global parameters in redis"
  after :build_pool, :seed_config do
    on roles(:web) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          rake 'config:seed'
        end
      end
    end
  end

  desc "Restart zartan-related monitored processes"
  after :seed_config, :restart do
    on roles(:web) do
      enabled_file = File.join(fetch(:deploy_to), 'shared', 'enabled')
      if test("ps cax | grep monit") and test("[ -f #{enabled_file} ]")
        # Only restart the application if monit is installed and running, and
        # the application has been enabled.
        execute :sudo, *%w(monit -g zartan_app restart all)
      else
        info "monit is not running, so we can't safely restart Zartan"
      end
    end
  end

end
