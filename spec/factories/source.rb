FactoryGirl.define do
  factory :digital_ocean_source, class: Sources::DigitalOcean do
    name "Example Source"
    type "Sources::DigitalOcean"
    max_proxies 5
    
    after(:build) do |source|
      source.config = {
        username: "username",
        password: "password",
        image_name: "image"
      }
    end
  end
end