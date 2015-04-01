require 'rails_helper'

RSpec.describe "api_keys/index", type: :view do

  before(:each) do
    assign(:api_keys, [
      create(:api_key),
      create(:api_key)
    ])
  end

  it "renders a list of api_keys" do
    render file: 'app/views/api_keys/index.html.erb'
  end
end
