module Phoenixqueue
  class Worker
    def self.claim_relation(queues:)
      Phoenixqueue::Job
        .where(status: "queued", queue: queues)
        .where("run_at <= ?", Time.now.utc)
        .order(priority: :desc, run_at: :asc, id: :asc)
        .lock("FOR UPDATE SKIP LOCKED")
    end

    def self.claim_next_job(queues:, worker_id:)
      # `worker_id` is used in later criteria when we transition the job to `running`.
      Phoenixqueue::Job.transaction do
        claim_relation(queues: queues).first
      end
    end
  end
end

