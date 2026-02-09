require "spec_helper"
require "rack/test"

RSpec.describe "Phoenixqueue Web UI" do
  include Rack::Test::Methods

  def app
    require_relative "dummy/config/environment"
    Dummy::Application
  end

  it "is mountable at /phoenixqueue" do
    get "/phoenixqueue"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("Dashboard")
  end

  it "shows counts by status and queue latency" do
    fixed_now = Time.utc(2026, 2, 9, 12, 0, 0)
    allow(Time).to receive(:now).and_return(fixed_now)

    Phoenixqueue::Job.create!(
      queue: "alpha",
      job_class: "AlphaJob",
      payload: { "x" => 1 },
      status: "queued",
      run_at: fixed_now - 61
    )
    Phoenixqueue::Job.create!(
      queue: "alpha",
      job_class: "AlphaJob",
      payload: { "x" => 2 },
      status: "queued",
      run_at: fixed_now - 5
    )
    Phoenixqueue::Job.create!(
      queue: "beta",
      job_class: "BetaJob",
      payload: { "y" => 1 },
      status: "running",
      run_at: fixed_now,
      locked_by: "worker-1",
      locked_at: fixed_now,
      lease_expires_at: fixed_now + 60
    )

    get "/phoenixqueue"
    expect(last_response.status).to eq(200)

    body = last_response.body
    expect(body).to include("Counts by status")
    expect(body).to match(/queued.*2/m)
    expect(body).to match(/running.*1/m)

    expect(body).to include("Queue latency")
    expect(body).to include("<code>alpha</code>")
    expect(body).to include(">61<")
  end

  it "renders the jobs index and supports filtering by status, queue, and job_class" do
    fixed_now = Time.utc(2026, 2, 9, 12, 0, 0)
    allow(Time).to receive(:now).and_return(fixed_now)

    queued_alpha = Phoenixqueue::Job.create!(
      queue: "alpha",
      job_class: "AlphaJob",
      payload: { "x" => 1 },
      status: "queued",
      run_at: fixed_now - 10
    )
    failed_beta = Phoenixqueue::Job.create!(
      queue: "beta",
      job_class: "CleanupJob",
      payload: { "y" => 1 },
      status: "failed",
      run_at: fixed_now - 10,
      finished_at: fixed_now - 1,
      last_error_class: "RuntimeError",
      last_error_message: "boom"
    )
    queued_beta_email = Phoenixqueue::Job.create!(
      queue: "beta",
      job_class: "EmailDeliveryJob",
      payload: { "z" => 1 },
      status: "queued",
      run_at: fixed_now - 10
    )

    get "/phoenixqueue/jobs"
    expect(last_response.status).to eq(200)

    get "/phoenixqueue/jobs?status=failed"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include(failed_beta.id.to_s)
    expect(last_response.body).not_to include(queued_alpha.id.to_s)
    expect(last_response.body).not_to include(queued_beta_email.id.to_s)

    get "/phoenixqueue/jobs?queue=beta"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include(failed_beta.id.to_s)
    expect(last_response.body).to include(queued_beta_email.id.to_s)
    expect(last_response.body).not_to include(queued_alpha.id.to_s)

    get "/phoenixqueue/jobs?job_class=Email"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include(queued_beta_email.id.to_s)
    expect(last_response.body).not_to include(queued_alpha.id.to_s)
    expect(last_response.body).not_to include(failed_beta.id.to_s)
  end

  it "renders the job detail and shows payload, error, attempts, timing, and progress" do
    fixed_now = Time.utc(2026, 2, 9, 12, 0, 0)

    job = Phoenixqueue::Job.create!(
      queue: "default",
      job_class: "ExampleJob",
      payload: { "args" => [{ "user_id" => 123 }], "job_class" => "ExampleJob" },
      status: "failed",
      run_at: fixed_now - 10,
      started_at: fixed_now - 9,
      finished_at: fixed_now - 1,
      attempt: 2,
      max_attempts: 5,
      last_error_class: "RuntimeError",
      last_error_message: "something went wrong",
      last_error_backtrace: "line1\nline2",
      progress: { "completed" => ["plan"], "current" => "execute" }
    )

    get "/phoenixqueue/jobs/#{job.id}"
    expect(last_response.status).to eq(200)

    body = last_response.body
    expect(body).to include(job.id.to_s)
    expect(body).to include("ExampleJob")
    expect(body).to include("2/5")
    expect(body).to include((fixed_now - 10).utc.iso8601)
    expect(body).to include((fixed_now - 9).utc.iso8601)
    expect(body).to include((fixed_now - 1).utc.iso8601)

    expect(body).to include("RuntimeError")
    expect(body).to include("something went wrong")
    expect(body).to include("Backtrace")

    expect(body).to include("&quot;user_id&quot;: 123")

    expect(body).to include("plan")
    expect(body).to include("execute")
  end

  it "redacts configured payload keys in the UI" do
    original = Phoenixqueue.config.redact_keys.dup
    Phoenixqueue.config.redact_keys = ["token"]

    job = Phoenixqueue::Job.create!(
      queue: "default",
      job_class: "SecretJob",
      payload: { "token" => "supersecret", "nested" => { "token" => "nestedsecret" } },
      status: "queued",
      run_at: Time.now.utc
    )

    get "/phoenixqueue/jobs/#{job.id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include(Phoenixqueue::Redaction::REDACTED)
    expect(last_response.body).not_to include("supersecret")
    expect(last_response.body).not_to include("nestedsecret")
  ensure
    Phoenixqueue.config.redact_keys = original
  end

  it "retries a job via POST /phoenixqueue/jobs/:id/retry" do
    fixed_now = Time.utc(2026, 2, 9, 12, 0, 0)
    allow(Time).to receive(:now).and_return(fixed_now)

    job = Phoenixqueue::Job.create!(
      queue: "default",
      job_class: "RetryMeJob",
      payload: { "args" => [1] },
      status: "failed",
      run_at: fixed_now - 60,
      finished_at: fixed_now - 30,
      attempt: 1,
      max_attempts: 5,
      last_error_class: "RuntimeError",
      last_error_message: "boom",
      progress: { "completed" => ["a"], "current" => "b" }
    )

    post "/phoenixqueue/jobs/#{job.id}/retry"
    expect(last_response.status).to eq(302)
    follow_redirect!
    expect(last_response.status).to eq(200)

    job.reload
    expect(job.status).to eq("queued")
    expect(job.run_at).to eq(fixed_now)
    expect(job.attempt).to eq(2)
    expect(job.last_error_class).to be_nil
    expect(job.last_error_message).to be_nil
    expect(job.progress).to eq({})

    retried = job.events.order(:id).last
    expect(retried.event_type).to eq("retried")
    expect(retried.data).to include("attempt" => 2, "reason" => "retry")
  end

  it "resumes a job via POST /phoenixqueue/jobs/:id/resume and preserves checkpoint progress" do
    fixed_now = Time.utc(2026, 2, 9, 12, 0, 0)
    allow(Time).to receive(:now).and_return(fixed_now)

    original_progress = { "completed" => ["a"], "current" => "b" }
    job = Phoenixqueue::Job.create!(
      queue: "default",
      job_class: "ResumeMeJob",
      payload: { "args" => [1] },
      status: "failed",
      run_at: fixed_now - 60,
      finished_at: fixed_now - 30,
      attempt: 1,
      max_attempts: 5,
      last_error_class: "RuntimeError",
      last_error_message: "boom",
      progress: original_progress
    )

    post "/phoenixqueue/jobs/#{job.id}/resume"
    expect(last_response.status).to eq(302)
    follow_redirect!
    expect(last_response.status).to eq(200)

    job.reload
    expect(job.status).to eq("queued")
    expect(job.run_at).to eq(fixed_now)
    expect(job.attempt).to eq(2)
    expect(job.progress).to eq(original_progress)

    retried = job.events.order(:id).last
    expect(retried.event_type).to eq("retried")
    expect(retried.data).to include("attempt" => 2, "reason" => "resume")
  end

  it "cancels a job via POST /phoenixqueue/jobs/:id/cancel and prevents further execution" do
    fixed_now = Time.utc(2026, 2, 9, 12, 0, 0)
    allow(Time).to receive(:now).and_return(fixed_now)

    job = Phoenixqueue::Job.create!(
      queue: "default",
      job_class: "CancelMeJob",
      payload: { "args" => [1] },
      status: "queued",
      run_at: fixed_now - 5
    )

    post "/phoenixqueue/jobs/#{job.id}/cancel"
    expect(last_response.status).to eq(302)
    follow_redirect!
    expect(last_response.status).to eq(200)

    job.reload
    expect(job.status).to eq("canceled")
    expect(job.finished_at).to eq(fixed_now)

    canceled = job.events.order(:id).last
    expect(canceled.event_type).to eq("canceled")

    claimed = Phoenixqueue::Worker.claim_next_job(queues: ["default"], worker_id: "worker-1")
    expect(claimed).to be_nil
  end
end

