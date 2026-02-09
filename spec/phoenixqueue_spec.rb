RSpec.describe Phoenixqueue do
  it "has a version number" do
    expect(Phoenixqueue::VERSION).to be_a(String)
    expect(Phoenixqueue::VERSION).not_to be_empty
  end
end

