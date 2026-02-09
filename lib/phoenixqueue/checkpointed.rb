require "active_support/concern"

module Phoenixqueue
  # Opt-in checkpoint DSL for ActiveJob jobs.
  #
  # Jobs restart from the beginning on retry/resume, but completed steps are
  # persisted to `phoenixqueue_jobs.progress` and will be skipped.
  module Checkpointed
    extend ActiveSupport::Concern

    def step(name, metadata: {})
      raise ArgumentError, "step requires a block" unless block_given?

      job_record = phoenixqueue_job_record
      # If we are not running inside a Phoenixqueue worker, just run the block.
      return yield unless job_record

      step_name = name.to_s
      progress = phoenixqueue_normalized_progress(job_record.progress)

      completed = Array(progress["completed"]).map(&:to_s)
      return if completed.include?(step_name)

      phoenixqueue_persist_progress!(
        job_record,
        progress.merge(
          "current" => step_name,
          "meta" => phoenixqueue_merged_meta(progress["meta"], step_name, metadata)
        ),
        event_action: "started",
        step_name: step_name
      )

      yield

      completed << step_name
      completed = completed.uniq

      phoenixqueue_persist_progress!(
        job_record,
        progress.merge(
          "completed" => completed,
          "current" => nil,
          "meta" => phoenixqueue_merged_meta(progress["meta"], step_name, metadata)
        ),
        event_action: "completed",
        step_name: step_name
      )
    end

    def steps_completed
      job_record = phoenixqueue_job_record
      return [] unless job_record

      phoenixqueue_normalized_progress(job_record.progress)["completed"] || []
    end

    def current_step
      job_record = phoenixqueue_job_record
      return nil unless job_record

      phoenixqueue_normalized_progress(job_record.progress)["current"]
    end

    private

    def phoenixqueue_job_record
      Phoenixqueue::Current.job_record || begin
        id = Phoenixqueue::Current.job_id
        id ? Phoenixqueue::Job.find_by(id: id) : nil
      end
    end

    def phoenixqueue_normalized_progress(progress)
      hash = progress.is_a?(Hash) ? progress : {}
      {
        "completed" => Array(hash["completed"] || hash[:completed]),
        "current" => (hash["current"] || hash[:current])&.to_s,
        "meta" => (hash["meta"] || hash[:meta] || {})
      }
    end

    def phoenixqueue_merged_meta(existing_meta, step_name, metadata)
      meta = existing_meta.is_a?(Hash) ? existing_meta.dup : {}
      return meta if metadata.nil? || metadata == {} # keep existing meta

      meta[step_name] = metadata
      meta
    end

    def phoenixqueue_persist_progress!(job_record, new_progress, event_action:, step_name:)
      Phoenixqueue::Job.transaction do
        job_record.update!(progress: new_progress)
        Phoenixqueue::JobEvent.create!(
          job_id: job_record.id,
          event_type: "checkpoint",
          data: { "step" => step_name, "action" => event_action }
        )
      end
    end
  end
end

