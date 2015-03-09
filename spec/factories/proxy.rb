FactoryGirl.define do
  factory :proxy do
    sequence(:host) { |n| "proxy#{n}.example.com" }
    sequence(:port) { |n| 10000 + n }
    
    association :source, factory: :digital_ocean_source
  end
end