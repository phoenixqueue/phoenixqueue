require "spec_helper"
require "rack/test"

RSpec.describe "Phoenixqueue Web UI" do
  include Rack::Test::Methods

  def app
    require_relative "dummy/config/environment"
    Dummy::Application
  end

  it "is mountable at /phoenixqueue" do
    get "/phoenixqueue"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("Dashboard")
  end
end

