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
end

