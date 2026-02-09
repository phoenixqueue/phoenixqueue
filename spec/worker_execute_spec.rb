RSpec.describe Phoenixqueue::Worker do
  class WorkerExecuteTestJob < ActiveJob::Base
    def perform(value)
      $phoenixqueue_worker_execute_value = value
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
end

