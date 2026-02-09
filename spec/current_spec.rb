require "spec_helper"

RSpec.describe Phoenixqueue::Current do
  class CurrentSpecJob < ActiveJob::Base
    def perform
      $phoenixqueue_current_seen_job_id = Phoenixqueue::Current.job_id
    end
  end

  class CurrentSpecFailingJob < ActiveJob::Base
    def perform
      raise "boom"
    end
  end

  it "is set during worker execution and cleared afterwards" do
    $phoenixqueue_current_seen_job_id = nil

    aj = CurrentSpecJob.new
    record = Phoenixqueue::Job.create!(
      job_class: "CurrentSpecJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1
    )

    Phoenixqueue::Worker.execute_job(record)

    expect($phoenixqueue_current_seen_job_id).to eq(record.id)
    expect(Phoenixqueue::Current.job_id).to be_nil
    expect(Phoenixqueue::Current.job_record).to be_nil
  end

  it "clears the thread-local context even if the job raises" do
    aj = CurrentSpecFailingJob.new
    record = Phoenixqueue::Job.create!(
      job_class: "CurrentSpecFailingJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1
    )

    expect { Phoenixqueue::Worker.execute_job(record) }.to raise_error(RuntimeError, "boom")
    expect(Phoenixqueue::Current.job_id).to be_nil
    expect(Phoenixqueue::Current.job_record).to be_nil
  end
end

