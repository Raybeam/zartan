FactoryGirl.define do
  factory :proxy_performance do
    association :proxy, factory: :proxy
    association :site, factory: :site
  end
end
