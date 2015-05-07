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

  context '#get_proxy' do
    it 'returns a proxy when reservation is unnecessary' do
      expect(site).to receive(:select_proxy).and_return(proxy)
      expect(client).to receive(:reserve_proxy).never

      proxy = client.get_proxy(site, 300)

      expect(proxy).to be_an_instance_of Proxy
    end

    it 'caches a proxy when a reservation is necessary' do
      no_proxy = Proxy::NotReady.new(1200, 1000, 1)
      expect(site).to receive(:select_proxy).and_return(no_proxy)
      expect(client).to receive(:reserve_proxy)

      result = client.get_proxy(site, 300)
      expect(result).to be_an_instance_of Proxy::NotReady
      expect(result.timeout).to eq 200
    end

    it 'returns a wait time when reserved proxy is too hot' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      client.reserve_proxy site, proxy.id, Time.now.to_i
      # "Wait" 30 seconds before calling get_proxy
      allow(Time).to receive(:now).and_return(now+30)

      result = client.get_proxy(site, 300)
      expect(result).to be_an_instance_of Proxy::NotReady
      expect(result.timeout).to eq 270
    end

    it 'returns a reserved proxy' do
      client.reserve_proxy site, proxy.id, Time.now.to_i

      # Check to make sure we got our reserved proxy
      result = client.get_proxy(site, 0)
      expect(result.id).to eq proxy.id

      # Check to make sure the reservation has been removed
      not_a_proxy = double
      expect(site).to receive(:select_proxy).and_return(not_a_proxy)
      expect(client.get_proxy(site,0)).to be not_a_proxy
    end
  end
end
