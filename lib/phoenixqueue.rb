require_relative "phoenixqueue/version"
require "logger"
require_relative "phoenixqueue/config"
require_relative "phoenixqueue/redaction"
require_relative "phoenixqueue/job"
require_relative "phoenixqueue/job_event"
require_relative "phoenixqueue/current"
require_relative "phoenixqueue/checkpointed"
require_relative "phoenixqueue/worker"
require_relative "phoenixqueue/sweeper"

begin
  require_relative "phoenixqueue/railtie"
  require_relative "phoenixqueue/web"
rescue LoadError
  # Rails is optional during early iterations / non-Rails usage.
end

module Phoenixqueue
  class Error < StandardError; end
end

