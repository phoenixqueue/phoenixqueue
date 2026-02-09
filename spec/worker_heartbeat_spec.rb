RSpec.describe Phoenixqueue::Worker do
  class WorkerHeartbeatTestJob < ActiveJob::Base
    def perform(duration)
      sleep duration
    end
  end

  it "extends lease_expires_at while a job is running" do
    aj = WorkerHeartbeatTestJob.new(1.0)
    initial_lease = Time.now.utc + 1

    record = Phoenixqueue::Job.create!(
      job_class: "WorkerHeartbeatTestJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1,
      locked_by: "w1",
      locked_at: Time.now.utc - 1,
      lease_expires_at: initial_lease
    )

    t = Thread.new do
      described_class.perform_job(record, heartbeat_interval: 0.1, lease_duration: 2)
    end

    sleep 0.35
    record.reload
    expect(record.lease_expires_at).to be > initial_lease

    t.join
  end
end

