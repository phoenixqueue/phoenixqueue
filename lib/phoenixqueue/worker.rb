module Phoenixqueue
  class Worker
    require "active_job"

    def self.claim_relation(queues:)
      Phoenixqueue::Job
        .where(status: "queued", queue: queues)
        .where("run_at <= ?", Time.now.utc)
        .order(priority: :desc, run_at: :asc, id: :asc)
        .lock("FOR UPDATE SKIP LOCKED")
    end

    def self.claim_next_job(queues:, worker_id:, lease_duration: 60)
      now = Time.now.utc
      Phoenixqueue::Job.transaction do
        job = claim_relation(queues: queues).first
        return nil unless job

        job.update!(
          status: "running",
          locked_by: worker_id,
          locked_at: now,
          lease_expires_at: now + lease_duration
        )

        job
      end
    end

    def self.execute_job(job_record)
      ActiveJob::Base.execute(job_record.payload)
    end
  end
end

