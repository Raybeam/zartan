FactoryGirl.define do
  factory :digital_ocean_source, class: Sources::DigitalOcean do
    name "Example Source"
    type "Sources::DigitalOcean"
    max_proxies 5
    
    after(:build) do |source|
      source.config = {
        'client_id' => "DEADBEEF_ID",
        'api_key' => "DEADBEEF_KEY",
        'image_name' => "image",
        'flavor_name' => "1337MB",
        'region_name' => "Nowhere 3",
        'proxy_port' => 2341
      }
    end
  end
end