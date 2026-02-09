module Phoenixqueue
  module Web
    class DashboardController < ApplicationController
      def show
        now = Time.now.utc

        @counts_by_status = Phoenixqueue::Job.group(:status).count

        oldest_by_queue = Phoenixqueue::Job.where(status: "queued").group(:queue).minimum(:run_at)
        @queue_latency_by_queue_seconds = oldest_by_queue.transform_values { |run_at| (now - run_at).to_i }
      end
    end
  end
end

