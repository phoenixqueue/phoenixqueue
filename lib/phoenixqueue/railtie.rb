require "rails/railtie"

module Phoenixqueue
  class Railtie < Rails::Railtie
    initializer "phoenixqueue.load_models" do
      require "phoenixqueue/job"
      require "phoenixqueue/job_event"
    end
  end
end

