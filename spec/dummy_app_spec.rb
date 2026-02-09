require "spec_helper"

RSpec.describe "Dummy Rails app" do
  it "can configure ActiveJob to use :phoenixqueue and enqueue a job" do
    require_relative "dummy/config/environment"

    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::PhoenixqueueAdapter)

    class DummyRailsEnqueueJob < ActiveJob::Base
      queue_as :dummy
      def perform(value); end
    end

    now = Time.now.utc
    DummyRailsEnqueueJob.perform_later("ok")

    record = Phoenixqueue::Job.order(:id).last
    expect(record.queue).to eq("dummy")
    expect(record.job_class).to eq("DummyRailsEnqueueJob")
    expect(record.status).to eq("queued")
    expect(record.run_at).to be_within(5).of(now)
  end
end

