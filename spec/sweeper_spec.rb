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

    fresh.reload
    expect(fresh.status).to eq("running")
  end

  it "ships a phoenixqueue executable with the sweep subcommand" do
    path = File.expand_path("../exe/phoenixqueue", __dir__)
    expect(File.exist?(path)).to eq(true)
  end
end

