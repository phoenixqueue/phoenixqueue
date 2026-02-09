require "active_record"

module Phoenixqueue
  class Job < ActiveRecord::Base
    self.table_name = "phoenixqueue_jobs"

    validates :queue, presence: true
    validates :job_class, presence: true
    validates :payload, presence: true
    validates :status, presence: true
    validates :run_at, presence: true
  end
end

