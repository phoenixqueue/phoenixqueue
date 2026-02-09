RSpec.describe Phoenixqueue::Worker do
  it "claims only runnable queued jobs" do
    future = Time.now.utc + 60
    ready = Time.now.utc - 1

    Phoenixqueue::Job.create!(
      job_class: "FutureJob",
      payload: { "job_class" => "FutureJob", "arguments" => [] },
      status: "queued",
      run_at: future
    )

    expected = Phoenixqueue::Job.create!(
      job_class: "ReadyJob",
      payload: { "job_class" => "ReadyJob", "arguments" => [] },
      status: "queued",
      run_at: ready,
      priority: 10
    )

    claimed = described_class.claim_next_job(queues: ["default"], worker_id: "w1")
    expect(claimed.id).to eq(expected.id)
  end

  it "transitions the claimed job to running with a lease" do
    job = Phoenixqueue::Job.create!(
      job_class: "ClaimableJob",
      payload: { "job_class" => "ClaimableJob", "arguments" => [] },
      status: "queued",
      run_at: Time.now.utc - 1
    )

    claimed = described_class.claim_next_job(queues: ["default"], worker_id: "worker-123", lease_duration: 120)

    expect(claimed.id).to eq(job.id)
    expect(claimed.status).to eq("running")
    expect(claimed.locked_by).to eq("worker-123")
    expect(claimed.locked_at).not_to be_nil
    expect(claimed.lease_expires_at).not_to be_nil
    expect(claimed.lease_expires_at).to be > claimed.locked_at

    job.reload
    expect(job.status).to eq("running")
    expect(job.locked_by).to eq("worker-123")
  end

  it "uses FOR UPDATE SKIP LOCKED when claiming" do
    sql = described_class.claim_relation(queues: ["default"]).to_sql
    expect(sql).to match(/FOR UPDATE SKIP LOCKED/i)
  end
end

