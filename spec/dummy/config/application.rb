require "logger"
require "rails"
require "rails/application"
require "active_job/railtie"

require "phoenixqueue"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new($stdout)
    config.log_level = :warn
  end
end

