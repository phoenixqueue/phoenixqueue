RSpec.describe Phoenixqueue::Worker do
  class WorkerExecuteTestJob < ActiveJob::Base
    def perform(value)
      $phoenixqueue_worker_execute_value = value
    end
  end

  class WorkerFailingTestJob < ActiveJob::Base
    def perform
      raise "boom"
    end
  end

  it "executes a claimed job via ActiveJob::Base.execute(payload)" do
    $phoenixqueue_worker_execute_value = nil

    aj = WorkerExecuteTestJob.new("hello")
    record = Phoenixqueue::Job.create!(
      job_class: "WorkerExecuteTestJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1
    )

    described_class.execute_job(record)
    expect($phoenixqueue_worker_execute_value).to eq("hello")
  end

  it "marks the job succeeded and writes a succeeded event on success" do
    aj = WorkerExecuteTestJob.new("ok")
    record = Phoenixqueue::Job.create!(
      job_class: "WorkerExecuteTestJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1,
      locked_by: "w1",
      locked_at: Time.now.utc - 1,
      lease_expires_at: Time.now.utc + 60
    )

    described_class.perform_job(record)

    record.reload
    expect(record.status).to eq("succeeded")
    expect(record.finished_at).not_to be_nil

    expect(Phoenixqueue::JobEvent.where(job_id: record.id, event_type: "succeeded").count).to eq(1)
  end

  it "requeues and writes a retried event on failure when attempts remain" do
    aj = WorkerFailingTestJob.new
    record = Phoenixqueue::Job.create!(
      job_class: "WorkerFailingTestJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1,
      attempt: 0,
      max_attempts: 3,
      locked_by: "w1",
      locked_at: Time.now.utc - 1,
      lease_expires_at: Time.now.utc + 60
    )

    result = described_class.perform_job(record)
    expect(result).to eq(:retried)

    record.reload
    expect(record.status).to eq("queued")
    expect(record.attempt).to eq(1)
    expect(record.last_error_class).to eq("RuntimeError")
    expect(record.last_error_message).to eq("boom")
    expect(record.last_error_backtrace).to include("worker_execute_spec.rb")
    expect(record.locked_by).to be_nil
    expect(record.run_at).to be > Time.now.utc

    expect(Phoenixqueue::JobEvent.where(job_id: record.id, event_type: "retried").count).to eq(1)
  end

  it "marks failed and writes a failed event when max_attempts is exceeded" do
    aj = WorkerFailingTestJob.new
    record = Phoenixqueue::Job.create!(
      job_class: "WorkerFailingTestJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1,
      attempt: 24,
      max_attempts: 25,
      locked_by: "w1",
      locked_at: Time.now.utc - 1,
      lease_expires_at: Time.now.utc + 60
    )

    result = described_class.perform_job(record)
    expect(result).to eq(:failed)

    record.reload
    expect(record.status).to eq("failed")
    expect(record.attempt).to eq(25)
    expect(record.finished_at).not_to be_nil

    expect(Phoenixqueue::JobEvent.where(job_id: record.id, event_type: "failed").count).to eq(1)
  end
end

