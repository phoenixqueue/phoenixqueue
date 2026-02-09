RSpec.describe "Phoenixqueue migrations" do
  it "creates phoenixqueue_jobs with required columns and indexes" do
    conn = ActiveRecord::Base.connection
    expect(conn.data_source_exists?("phoenixqueue_jobs")).to eq(true)

    cols = conn.columns("phoenixqueue_jobs").map(&:name)
    expect(cols).to include(
      "queue",
      "job_class",
      "payload",
      "status",
      "priority",
      "run_at",
      "attempt",
      "max_attempts",
      "locked_by",
      "locked_at",
      "lease_expires_at",
      "started_at",
      "finished_at",
      "last_error_class",
      "last_error_message",
      "last_error_backtrace",
      "progress",
      "created_at",
      "updated_at"
    )

    indexes = conn.indexes("phoenixqueue_jobs").map { |i| i.columns.sort }
    expect(indexes).to include(%w[id priority run_at status].sort)
    expect(indexes).to include(%w[queue run_at status].sort)
    expect(indexes).to include(%w[created_at job_class status].sort)
  end

  it "creates phoenixqueue_job_events with required columns and index" do
    conn = ActiveRecord::Base.connection
    expect(conn.data_source_exists?("phoenixqueue_job_events")).to eq(true)

    cols = conn.columns("phoenixqueue_job_events").map(&:name)
    expect(cols).to include("job_id", "event_type", "data", "created_at")

    indexes = conn.indexes("phoenixqueue_job_events").map { |i| i.columns.sort }
    expect(indexes).to include(%w[id job_id].sort)
  end
end

