module Phoenixqueue
  module Web
    class JobsController < ApplicationController
      def index
        @status = presence(params[:status])
        @queue = presence(params[:queue])
        @job_class = presence(params[:job_class])

        scope = Phoenixqueue::Job.all
        scope = scope.where(status: @status) if @status
        scope = scope.where(queue: @queue) if @queue
        scope = scope.where("job_class ILIKE ?", "%#{@job_class}%") if @job_class

        @jobs = scope.order(id: :desc).limit(200)
      end

      def show
        @job = Phoenixqueue::Job.find(params[:id])
        @events = @job.events.order(id: :asc)
      end

      def retry
        job = Phoenixqueue::Job.find(params[:id])
        requeue!(job, preserve_progress: false)
        redirect_to job_path(job.id)
      end

      def resume
        job = Phoenixqueue::Job.find(params[:id])
        requeue!(job, preserve_progress: true)
        redirect_to job_path(job.id)
      end

      def cancel
        job = Phoenixqueue::Job.find(params[:id])
        cancel!(job)
        redirect_to job_path(job.id)
      end

      private

      def requeue!(job, preserve_progress:)
        now = Time.now.utc
        attempt = job.attempt.to_i + 1

        Phoenixqueue::Job.transaction do
          attrs = {
            status: "queued",
            run_at: now,
            attempt: attempt,
            locked_by: nil,
            locked_at: nil,
            lease_expires_at: nil,
            finished_at: nil,
            last_error_class: nil,
            last_error_message: nil,
            last_error_backtrace: nil
          }
          attrs[:progress] = {} unless preserve_progress

          job.update!(attrs)
          Phoenixqueue::JobEvent.create!(
            job_id: job.id,
            event_type: "retried",
            data: { "attempt" => attempt, "reason" => (preserve_progress ? "resume" : "retry") }
          )
        end
      end

      def cancel!(job)
        now = Time.now.utc

        Phoenixqueue::Job.transaction do
          job.update!(
            status: "canceled",
            finished_at: now,
            locked_by: nil,
            locked_at: nil,
            lease_expires_at: nil
          )
          Phoenixqueue::JobEvent.create!(job_id: job.id, event_type: "canceled", data: {})
        end
      end

      def presence(value)
        v = value.to_s.strip
        v.empty? ? nil : v
      end
    end
  end
end

