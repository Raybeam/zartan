FactoryGirl.define do
  factory :blank_source, class: Source do
    name "Example Source"
    type "Source"
    username "username"
    password "password"
    max_proxies 5
  end
end