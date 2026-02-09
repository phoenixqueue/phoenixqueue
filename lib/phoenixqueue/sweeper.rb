module Phoenixqueue
  class Sweeper
    def self.sweep!(requeue: false)
      now = Time.now.utc

      scope = Phoenixqueue::Job.where(status: "running").where("lease_expires_at < ?", now)
      scope.find_each do |job|
        job.update!(
          status: "interrupted",
          locked_by: nil,
          locked_at: nil,
          lease_expires_at: nil
        )
      end
    end
  end
end

