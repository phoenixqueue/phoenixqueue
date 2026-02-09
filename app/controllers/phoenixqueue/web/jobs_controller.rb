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

      private

      def presence(value)
        v = value.to_s.strip
        v.empty? ? nil : v
      end
    end
  end
end

