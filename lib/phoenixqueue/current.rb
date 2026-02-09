module Phoenixqueue
  # Thread-local context for the currently executing Phoenixqueue job.
  #
  # This allows checkpointed jobs to persist progress against the correct
  # `phoenixqueue_jobs` row while running inside a worker thread.
  module Current
    THREAD_KEY = :__phoenixqueue_current

    def self.job_id
      state[:job_id]
    end

    def self.job_record
      state[:job_record]
    end

    def self.job_id=(value)
      state[:job_id] = value
    end

    def self.job_record=(value)
      state[:job_record] = value
    end

    def self.set(job_id:, job_record: nil)
      self.job_id = job_id
      self.job_record = job_record
    end

    def self.set_from_record(job_record)
      set(job_id: job_record.id, job_record: job_record)
    end

    def self.clear!
      Thread.current[THREAD_KEY] = nil
    end

    def self.state
      Thread.current[THREAD_KEY] ||= {}
    end
  end
end

