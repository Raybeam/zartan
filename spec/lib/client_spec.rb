require 'client'

require 'spec_helper'

RSpec.describe Client, redis:true do
  let(:client) {Client.create}
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}

  it 'is valid when recently created' do
    expect(client.valid?).to be_truthy
  end

  it 'is not valid when initialized from meaningless data' do
    dead_client = Client.new('foo')

    expect(dead_client.valid?).to be_falsey
  end

  it 'finds existing client data' do
    built_client = Client[client.id]

    expect(built_client.valid?).to be_truthy
  end

  it "doesn't find expired client data" do
    built_client = Client[1]

    expect(built_client.valid?).to be_falsey
  end

  it 'retrieves a proxy' do
    client.reserve_proxy site, proxy, 0

    expect(client.get_proxy(site).id).to eq proxy.id
  end

  it 'does not retrieve a hot proxy' do
    client.reserve_proxy site, proxy, 300

    expect(client.get_proxy(site)).to be_an_instance_of Proxy::NoColdProxy
  end

  it 'does not retrieve a proxy if none is cached' do
    expect(client.get_proxy(site)).to be Proxy::NoProxy
  end
end
