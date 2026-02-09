# Phoenixqueue

Phoenixqueue is a Postgres-backed background job system with an ActiveJob adapter, a worker, checkpoint/resume, and a Web UI (Rails engine).

## Semantics (v1)

- **At-least-once**: jobs may run more than once (crash, timeout, manual retry/resume). Design jobs to be idempotent.
- **Interruption**: workers use a lease (`lease_expires_at`). If a worker dies, jobs can become stale; run the sweeper to mark them `interrupted` (optionally requeue them).
- **Checkpoint/resume**: checkpoints are explicit `step(:name) { ... }`. Completed steps are persisted; on retry/resume, completed steps are skipped. If a process dies mid-step, that step re-runs (steps must be idempotent).

## Running Phoenixqueue

### Database

Phoenixqueue uses Postgres. In your environment set:

- `PHOENIXQUEUE_DATABASE_URL` (development/production)
- `PHOENIXQUEUE_TEST_DATABASE_URL` (test)

### Migrations

Install and run migrations in the host app:

```bash
bin/rails railties:install:migrations
bin/rails db:migrate
```

### ActiveJob adapter

Configure ActiveJob to use Phoenixqueue:

```ruby
# config/application.rb (or an environment file)
config.active_job.queue_adapter = :phoenixqueue
```

### Worker (minimal loop)

Phoenixqueue exposes primitives in `Phoenixqueue::Worker`. A minimal worker loop might look like:

```ruby
worker_id = "#{Socket.gethostname}:#{$$}"
queues = ["default"]

loop do
  job = Phoenixqueue::Worker.claim_next_job(queues: queues, worker_id: worker_id, lease_duration: 60)
  if job
    Phoenixqueue::Worker.perform_job(job, heartbeat_interval: 5, lease_duration: 60)
  else
    sleep 1
  end
end
```

### Sweeper (stale running jobs)

The `phoenixqueue` CLI supports:

```bash
phoenixqueue sweep
phoenixqueue sweep --requeue
```

## Web UI (Rails engine)

Mount the engine in your Rails app:

```ruby
# config/routes.rb
mount Phoenixqueue::Web::Engine => "/phoenixqueue"
```

Then visit `/phoenixqueue`.

### Payload redaction (UI)

To avoid leaking secrets in the UI payload viewer:

```ruby
Phoenixqueue.configure do |config|
  config.redact_keys = %w[token password authorization]
end
```


