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

  factory :linode_source, class: Sources::Linode do
    name "Example Linode Source"
    type "Sources::Linode"
    max_proxies 5

    after(:build) do |source|
      source.config = {
        'name' => "7-5-6-4-12345-1234567890",
        'api_key' => "BOMB_DIGGITY_KEY",
        'root_password' => "BOMB_DIGGITY_PW",
        'image_name' => "image",
        'image_id' => 4,
        'flavor_name' => "1337MB",
        'flavor_id' => 5,
        'kernel_name' => "Latest 64 bit",
        'kernel_id' => 6,
        'data_center_name' => "Somewhere 42",
        'data_center_id' => 7,
        'proxy_port' => 3675
      }
    end
  end

  factory :joyent_source, class: Sources::Joyent do
    name "Example Joyent Source"
    type "Sources::Joyent"
    max_proxies 5

    after(:build) do |source|
      source.config = {
        'username' => "joyent_username",
        'password' => "SECRET_TUNNEL",
        'datacenter' => "joyentcloud_test_location",
        'image_id' => "proxy_image",
        'package_id' => "flavor_name",
        'proxy_port' => 1337
      }
    end
  end
end
