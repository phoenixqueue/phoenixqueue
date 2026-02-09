require_relative "phoenixqueue/version"
require "logger"
require_relative "phoenixqueue/job"
require_relative "phoenixqueue/job_event"
require_relative "phoenixqueue/worker"

begin
  require_relative "phoenixqueue/railtie"
rescue LoadError
  # Rails is optional during early iterations / non-Rails usage.
end

module Phoenixqueue
  class Error < StandardError; end
end

