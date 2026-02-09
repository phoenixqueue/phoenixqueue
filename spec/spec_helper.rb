require "phoenixqueue"
require_relative "support/test_database"

RSpec.configure do |config|
  config.before(:suite) do
    Phoenixqueue::TestDatabase.connect!
    Phoenixqueue::TestDatabase.migrate!
  end

  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

