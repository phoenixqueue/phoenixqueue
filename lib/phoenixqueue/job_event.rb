require "active_record"

module Phoenixqueue
  class JobEvent < ActiveRecord::Base
    self.table_name = "phoenixqueue_job_events"

    belongs_to :job,
      class_name: "Phoenixqueue::Job",
      foreign_key: :job_id,
      inverse_of: :events
  end
end

