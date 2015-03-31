require 'resque/tasks'
require 'resque/pool/tasks'
require 'resque/scheduler/tasks'

require 'resque-scheduler'

namespace :resque do
  task :setup => :environment

  namespace :pool do
    task :setup do
      ActiveRecord::Base.connection.disconnect!
      
      Resque::Pool.after_prefork do |job|
        ActiveRecord::Base.establish_connection
        Resque.redis.client.reconnect
      end
    end
  end

  task :setup_schedule => :setup do
    Resque.schedule = YAML.load_file(Rails.root.join('config/resque_schedule.yml'))
  end

  task :scheduler_setup => :setup_schedule
end
