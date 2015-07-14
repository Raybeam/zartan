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

  factory :joynet_source, class: Sources::Joyent do
    name "Example Joyent Source"
    type "Sources::Joyent"
    max_proxies 5

    after(:build) do |source|
      source.config = {
        'username' => "proxy-uuid",
        'password' => "SECRET_TUNNEL",
        'datacenter' => "joyentcloud_test_location",
        'image_id' => "proxy_image",
        'package_id' => "flavor_name",
        'proxy_port' => 1337
      }
    end
  end
end
