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
        'image_id' => 1,
        'flavor_name' => "1337MB",
        'flavor_id' => 2,
        'region_name' => "Nowhere 3",
        'region_id' => 3,
        'proxy_port' => 2341
      }
    end
  end
end