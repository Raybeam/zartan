
namespace :config do
  desc "Set default config values where said values are undefined"
  task :seed => [:environment] do
    config = Zartan::Config.new
    defaults = YAML.load_file(Rails.root.join('config/default_settings.yml'))['defaults']
    
    defaults.each_pair do |name, value|
      unless config.keys.include? name
        config[name] = value
      end
    end
  end
  
  desc "Generate a resque_pool config file"
  task :pool => [:environment] do
    workers = { 'default' => 1 }
    Zartan::SourceType.all.each do |type|
      workers[type.queue] = 1
    end
    
    YAML.dump(
      workers,
      File.open(Rails.root.join('config/resque_pool.yml'), 'w')
    )
  end
end