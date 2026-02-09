require "spec_helper"

RSpec.describe Phoenixqueue::Checkpointed do
  class CheckpointedSpecJob < ActiveJob::Base
    include Phoenixqueue::Checkpointed

    def perform
      step(:one) { $phoenixqueue_checkpoint_calls << :one }
      step(:two) do
        $phoenixqueue_checkpoint_calls << :two
        if $phoenixqueue_checkpoint_fail_once
          $phoenixqueue_checkpoint_fail_once = false
          raise "boom"
        end
      end
      step(:three) { $phoenixqueue_checkpoint_calls << :three }
    end
  end

  it "persists completed steps and skips them on retry; failed steps rerun" do
    $phoenixqueue_checkpoint_calls = []
    $phoenixqueue_checkpoint_fail_once = true

    aj = CheckpointedSpecJob.new
    record = Phoenixqueue::Job.create!(
      job_class: "CheckpointedSpecJob",
      payload: aj.serialize,
      status: "running",
      run_at: Time.now.utc - 1,
      attempt: 0,
      max_attempts: 5
    )

    first_result = Phoenixqueue::Worker.perform_job(record, heartbeat_interval: 0.01, lease_duration: 1)
    expect(first_result).to eq(:retried)

    record.reload
    expect(record.status).to eq("queued")
    expect(record.attempt).to eq(1)
    expect(record.progress["completed"]).to eq(["one"])
    expect(record.progress["current"]).to eq("two")
    expect($phoenixqueue_checkpoint_calls).to eq([:one, :two])

    # Simulate the job being claimed again and running.
    record.update!(status: "running", run_at: Time.now.utc - 1)

    second_result = Phoenixqueue::Worker.perform_job(record, heartbeat_interval: 0.01, lease_duration: 1)
    expect(second_result).to eq(:succeeded)

    record.reload
    expect(record.status).to eq("succeeded")
    expect(record.progress["current"]).to be_nil
    expect(record.progress["completed"]).to match_array(%w[one two three])

    # Step :one should be skipped on retry, step :two should rerun after failing mid-step.
    expect($phoenixqueue_checkpoint_calls).to eq([:one, :two, :two, :three])
  end
end

