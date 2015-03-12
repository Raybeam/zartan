zartan_root = "/var/www/zartan"

worker_processes 4

working_directory "#{zartan_root}/current"

listen "#{zartan_root}/shared/pids/.unicorn.sock"
pid "#{zartan_root}/shared/pids/unicorn.pid"

stderr_path "#{zartan_root}/shared/log/unicorn.stderr.log"
stdout_path "#{zartan_root}/shared/log/unicorn.stdout.log"


preload_app true
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end

before_fork do |server, worker|
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
  end
end

after_fork do |server, worker|
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end
end
