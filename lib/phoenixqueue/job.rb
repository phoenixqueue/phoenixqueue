require "active_record"

module Phoenixqueue
  class Job < ActiveRecord::Base
    self.table_name = "phoenixqueue_jobs"

    has_many :events,
      class_name: "Phoenixqueue::JobEvent",
      foreign_key: :job_id,
      inverse_of: :job,
      dependent: :delete_all

    validates :queue, presence: true
    validates :job_class, presence: true
    validates :payload, presence: true
    validates :status, presence: true
    validates :run_at, presence: true

    after_create :emit_enqueued_event

    private

    def emit_enqueued_event
      Phoenixqueue::JobEvent.create!(job_id: id, event_type: "enqueued", data: {})
    end
  end
end

