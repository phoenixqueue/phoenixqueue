RSpec.describe Phoenixqueue::Sweeper do
  it "marks stale running jobs as interrupted" do
    stale = Phoenixqueue::Job.create!(
      job_class: "StaleJob",
      payload: { "job_class" => "StaleJob", "arguments" => [] },
      status: "running",
      run_at: Time.now.utc - 60,
      locked_by: "w1",
      locked_at: Time.now.utc - 60,
      lease_expires_at: Time.now.utc - 1
    )

    fresh = Phoenixqueue::Job.create!(
      job_class: "FreshJob",
      payload: { "job_class" => "FreshJob", "arguments" => [] },
      status: "running",
      run_at: Time.now.utc - 60,
      locked_by: "w1",
      locked_at: Time.now.utc - 60,
      lease_expires_at: Time.now.utc + 60
    )

    described_class.sweep!

    stale.reload
    expect(stale.status).to eq("interrupted")
    expect(stale.locked_by).to be_nil
    expect(stale.lease_expires_at).to be_nil
    expect(Phoenixqueue::JobEvent.where(job_id: stale.id, event_type: "interrupted").count).to eq(1)

    fresh.reload
    expect(fresh.status).to eq("running")
  end

  it "optionally requeues interrupted jobs back to queued" do
    stale = Phoenixqueue::Job.create!(
      job_class: "StaleJob",
      payload: { "job_class" => "StaleJob", "arguments" => [] },
      status: "running",
      run_at: Time.now.utc - 60,
      locked_by: "w1",
      locked_at: Time.now.utc - 60,
      lease_expires_at: Time.now.utc - 1
    )

    described_class.sweep!(requeue: true)

    stale.reload
    expect(stale.status).to eq("queued")
    expect(Phoenixqueue::JobEvent.where(job_id: stale.id, event_type: "retried").count).to eq(1)
  end

  it "ships a phoenixqueue executable with the sweep subcommand" do
    path = File.expand_path("../exe/phoenixqueue", __dir__)
    expect(File.exist?(path)).to eq(true)
  end
end

