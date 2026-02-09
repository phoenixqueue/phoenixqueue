require "logger"
require "rails"
require "rails/application"
require "action_controller/railtie"
require "active_job/railtie"

require "phoenixqueue"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new($stdout)
    config.log_level = :warn
    config.active_job.queue_adapter = :phoenixqueue
    config.secret_key_base = "phoenixqueue_dummy_secret_key_base"
    config.hosts.clear if config.respond_to?(:hosts)
  end
end

