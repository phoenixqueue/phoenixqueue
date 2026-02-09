RSpec.describe "Phoenixqueue model loading" do
  it "loads Phoenixqueue::Job and Phoenixqueue::JobEvent" do
    require "phoenixqueue"

    expect(defined?(Phoenixqueue::Job)).to eq("constant")
    expect(defined?(Phoenixqueue::JobEvent)).to eq("constant")

    expect(Phoenixqueue::Job).to be < ActiveRecord::Base
    expect(Phoenixqueue::JobEvent).to be < ActiveRecord::Base
  end
end

