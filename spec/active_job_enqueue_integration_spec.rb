require "spec_helper"

RSpec.describe "Phoenixqueue ActiveJob adapter integration" do
  class IntegrationEnqueueJob < ActiveJob::Base
    queue_as :urgent
    def perform(value); end
  end

  around do |example|
    previous = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :phoenixqueue
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
  end

  it "persists a phoenixqueue_jobs row when enqueuing via ActiveJob" do
    now = Time.now.utc

    IntegrationEnqueueJob.perform_later("hi")

    record = Phoenixqueue::Job.order(:id).last
    expect(record.queue).to eq("urgent")
    expect(record.job_class).to eq("IntegrationEnqueueJob")
    expect(record.status).to eq("queued")
    expect(record.run_at).to be_within(5).of(now)
    expect(record.payload["job_class"]).to eq("IntegrationEnqueueJob")
    expect(record.payload["arguments"]).to eq(["hi"])
  end
end

