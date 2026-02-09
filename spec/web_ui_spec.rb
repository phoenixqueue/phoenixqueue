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
end

