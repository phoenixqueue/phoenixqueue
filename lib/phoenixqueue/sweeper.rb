module Phoenixqueue
  class Sweeper
    def self.sweep!(requeue: false)
      now = Time.now.utc

      scope = Phoenixqueue::Job.where(status: "running").where("lease_expires_at < ?", now)
      scope.find_each do |job|
        Phoenixqueue::Job.transaction do
          job.update!(
            status: "interrupted",
            locked_by: nil,
            locked_at: nil,
            lease_expires_at: nil
          )
          Phoenixqueue::JobEvent.create!(job_id: job.id, event_type: "interrupted", data: {})
        end
      end
    end
  end
end

