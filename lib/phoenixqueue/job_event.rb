require "active_record"

module Phoenixqueue
  class JobEvent < ActiveRecord::Base
    self.table_name = "phoenixqueue_job_events"
  end
end

