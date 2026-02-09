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

    def self.ack_success(job_record)
      now = Time.now.utc
      Phoenixqueue::Job.transaction do
        job_record.update!(
          status: "succeeded",
          finished_at: now,
          locked_by: nil,
          locked_at: nil,
          lease_expires_at: nil
        )
        Phoenixqueue::JobEvent.create!(job_id: job_record.id, event_type: "succeeded", data: {})
      end
    end

    def self.perform_job(job_record)
      execute_job(job_record)
      ack_success(job_record)
      :succeeded
    rescue StandardError => e
      handle_failure(job_record, e)
    end

    def self.backoff_seconds(attempt)
      [2**(attempt - 1), 300].min
    end

    def self.handle_failure(job_record, exception)
      now = Time.now.utc
      attempt = job_record.attempt.to_i + 1

      error_attrs = {
        attempt: attempt,
        last_error_class: exception.class.name,
        last_error_message: exception.message,
        last_error_backtrace: Array(exception.backtrace).join("\n"),
        locked_by: nil,
        locked_at: nil,
        lease_expires_at: nil
      }

      if attempt < job_record.max_attempts.to_i
        run_at = now + backoff_seconds(attempt)
        Phoenixqueue::Job.transaction do
          job_record.update!(
            **error_attrs,
            status: "queued",
            run_at: run_at
          )
          Phoenixqueue::JobEvent.create!(
            job_id: job_record.id,
            event_type: "retried",
            data: { "attempt" => attempt, "run_at" => run_at.iso8601 }
          )
        end
        :retried
      else
        Phoenixqueue::Job.transaction do
          job_record.update!(
            **error_attrs,
            status: "failed",
            finished_at: now
          )
          Phoenixqueue::JobEvent.create!(job_id: job_record.id, event_type: "failed", data: { "attempt" => attempt })
        end
        :failed
      end
    end
  end
end

