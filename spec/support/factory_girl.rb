RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  
  config.before(:suite) do
    FactoryGirl.find_definitions
    begin
      DatabaseCleaner.start
      FactoryGirl.lint
    ensure
      DatabaseCleaner.clean
    end
  end
end