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
        'name' => "proxy-unique-identifier-here",
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
end