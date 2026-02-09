require "active_record"

module Phoenixqueue
  class Job < ActiveRecord::Base
    self.table_name = "phoenixqueue_jobs"
  end
end

