require "active_job"
require "phoenixqueue/job"
require "phoenixqueue/job_event"

module ActiveJob
  module QueueAdapters
    class PhoenixqueueAdapter
      def enqueue(job)
        enqueue_at(job, Time.now.utc.to_f)
      end

      def enqueue_at(job, timestamp)
        run_at = Time.at(timestamp).utc
        queue = job.queue_name
        queue = "default" if queue.nil? || queue == ""

        record = Phoenixqueue::Job.create!(
          queue: queue,
          job_class: job.class.name,
          payload: job.serialize,
          status: "queued",
          run_at: run_at,
          priority: job.priority || 0
        )

        job.provider_job_id = record.id.to_s if job.respond_to?(:provider_job_id=)
        record
      end
    end
  end
end

