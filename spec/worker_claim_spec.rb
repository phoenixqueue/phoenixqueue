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

  it "uses FOR UPDATE SKIP LOCKED when claiming" do
    sql = described_class.claim_relation(queues: ["default"]).to_sql
    expect(sql).to match(/FOR UPDATE SKIP LOCKED/i)
  end
end

