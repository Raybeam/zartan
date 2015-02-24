FactoryGirl.define do
  factory :proxy do
    host "example.com"
    port 12345
    
    association :source, factory: :blank_source
  end
end