RSpec.describe "Phoenixqueue job events" do
  it "writes an enqueued event when a job is created" do
    job = Phoenixqueue::Job.create!(
      job_class: "ExampleJob",
      payload: { "job_class" => "ExampleJob", "arguments" => [] },
      status: "queued",
      run_at: Time.now.utc
    )

    events = Phoenixqueue::JobEvent.where(job_id: job.id, event_type: "enqueued")
    expect(events.count).to eq(1)
  end
end

