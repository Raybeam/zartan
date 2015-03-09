FactoryGirl.define do
  factory :site do
    sequence(:name) { |n| "site#{n}.example.com" }
  end
end