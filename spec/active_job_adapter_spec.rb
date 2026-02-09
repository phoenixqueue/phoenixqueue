require "spec_helper"
require "active_job/queue_adapters/phoenixqueue_adapter"

RSpec.describe ActiveJob::QueueAdapters::PhoenixqueueAdapter do
  let(:adapter) { described_class.new }

  it "enqueues a job row with expected fields" do
    job_class = stub_const("AdapterEnqueueJob", Class.new(ActiveJob::Base) do
      queue_as :critical
      def perform(value); end
    end)

    job = job_class.new("hello")
    now = Time.now.utc

    record = adapter.enqueue(job)

    expect(record).to be_a(Phoenixqueue::Job)
    expect(record.queue).to eq("critical")
    expect(record.job_class).to eq(job_class.name)
    expect(record.status).to eq("queued")
    expect(record.run_at).to be_within(5).of(now)
    expect(record.payload).to be_a(Hash)
    expect(record.payload["job_class"]).to eq(job_class.name)
    expect(record.payload["arguments"]).to eq(["hello"])
    expect(Phoenixqueue::JobEvent.where(job_id: record.id, event_type: "enqueued").count).to eq(1)
  end

  it "supports enqueue_at with an explicit timestamp" do
    job_class = stub_const("AdapterEnqueueAtJob", Class.new(ActiveJob::Base) do
      queue_as :low
      def perform(value); end
    end)

    scheduled = Time.now.utc + 60
    job = job_class.new("later")

    record = adapter.enqueue_at(job, scheduled.to_f)

    expect(record.queue).to eq("low")
    expect(record.status).to eq("queued")
    expect(record.run_at).to be_within(2).of(scheduled)
  end
end

