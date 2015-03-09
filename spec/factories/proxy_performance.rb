FactoryGirl.define do
  factory :proxy_performance do
    association :proxy, factory: :proxy, host: 'performance_host'
    association :site, factory: :site, name: 'performance_site'
  end
end
