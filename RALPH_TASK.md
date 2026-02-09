---
task: "Build phoenixqueue: a Postgres-backed ActiveJob adapter + worker + checkpoint/resume + modern Web UI (Rails engine)"
test_command: "test -f RALPH_TASK.md && grep -nE '^[0-9]+\\. \\[ \\] ' RALPH_TASK.md | head -n 30"
max_iterations: 20
---

# Phoenixqueue

**Phoenixqueue** is a Postgres-backed background job system with ActiveJob compatibility, checkpoint/resume, and a modern Web UI.

It provides:
- Rails ActiveJob compatibility (drop-in adapter)
- Postgres as the only backend (no Redis)
- Checkpointed steps so an interrupted job can restart from where it was
- A useful Web UI (dashboard, job list, detail, retry/resume/cancel)
- A pure Ruby gem + Rails engine

Phoenixqueue is **not** Temporal. No deterministic replay. No workflow engine. No signals. No waiting/timers beyond `enqueue_at`.

**Note for Ralph:** The task file must be named `RALPH_TASK.md` in the repo root. Copy/rename from `RALPH_TASKS.md` if needed.

---

## What Phoenixqueue is (and is not)

### Phoenixqueue **is**
- An ActiveJob adapter: `config.active_job.queue_adapter = :phoenixqueue`
- A worker process that claims jobs from Postgres, executes them via ActiveJob, records status + errors + timing, and supports threads for I/O concurrency
- A checkpoint DSL (opt-in, per job): job restarts from the beginning but skips completed steps; step completion is recorded in Postgres; interrupted mid-step means that step re-runs (step must be idempotent)
- A Rails engine Web UI: dashboard, searchable job list (status, queue, job_class), job detail (timeline, error, payload, checkpoints), safe actions (retry/resume/cancel)

### Phoenixqueue **is not**
- A general workflow engine (Temporal-like)
- Deterministic replay
- Distributed "exactly once"
- Redis support
- Multi-DB support (no MySQL in v1)
- Cron scheduler UI, DAGs, fan-out/fan-in
- A multi-tenant SaaS control plane

---

## Target environment

- Ruby 3.2+ (prefer 3.3)
- Rails 7.0+ (engine + ActiveJob adapter)
- Postgres 13+ (local dev via Docker)
- `./bin/setup` and `./bin/test` should work if Docker is installed

---

## Naming and structure

- Gem name: `phoenixqueue`
- Top-level module: `Phoenixqueue`
- Engine namespace: `Phoenixqueue::Web`
- Tables: `phoenixqueue_jobs`, `phoenixqueue_job_events`

---

## Core semantics

### Delivery semantics
- At-least-once execution.
- A job may run more than once (crash, timeout, manual retry).
- Users must design jobs to be idempotent (or use the checkpoint DSL carefully).

### Interruption semantics
- If a worker dies mid-job, the job may remain `running` until reclaimed.
- The system must detect stale running jobs (lease expiration + sweeper) and mark them `interrupted`.

### Checkpoint semantics (resume)
- Checkpoints are explicit: `step(:name) { ... }`.
- A step is done only after its block completes successfully.
- On resume/retry, previously completed steps are skipped.
- If interrupted mid-step, the step is not recorded complete and will run again.

---

## Persistence design

### `phoenixqueue_jobs` (v1, minimal columns)

Use ActiveRecord migration. Types are guidance.

- `id` (bigint primary key)
- `queue` (string, not null, default "default")
- `job_class` (string, not null) — ActiveJob class name
- `payload` (jsonb, not null) — ActiveJob serialized payload (hash)
- `status` (string, not null) — `queued`, `running`, `succeeded`, `failed`, `interrupted`, `canceled`
- `priority` (integer, not null, default 0)
- `run_at` (timestamptz, not null, default now()) — for enqueue_at
- `attempt` (integer, not null, default 0)
- `max_attempts` (integer, not null, default 25)
- `locked_by` (string, null) — worker identity
- `locked_at` (timestamptz, null)
- `lease_expires_at` (timestamptz, null)
- `started_at` (timestamptz, null)
- `finished_at` (timestamptz, null)
- `last_error_class` (string, null)
- `last_error_message` (text, null)
- `last_error_backtrace` (text, null)
- `progress` (jsonb, not null, default `{}`) — checkpoints, current step, optional metadata
- `created_at`, `updated_at`

Indexes (minimum):
- `(status, run_at, priority, id)` for claiming
- `(queue, status, run_at)`
- `(job_class, status, created_at)`

### `phoenixqueue_job_events` (append-only timeline for UI)

- `id`, `job_id` (fk), `event_type` (string), `data` (jsonb, default `{}`), `created_at`
- `event_type`: `enqueued`, `started`, `checkpoint`, `failed`, `retried`, `succeeded`, `interrupted`, `canceled`
- Index: `(job_id, id)` or `(job_id, created_at)`

---

## Worker algorithm (SKIP LOCKED)

### Claim (atomic)
Within a transaction: find one job (status = `queued`, run_at <= now(), queue in configured queues, order by priority desc, run_at asc, id asc, `FOR UPDATE SKIP LOCKED`, limit 1). Update to `status = running`, `locked_by`, `locked_at`, `lease_expires_at = now() + lease_duration`, `started_at = now()` if null. Insert `job_event(started)`. Commit; execute outside transaction.

### Heartbeat
While the job is running, a background heartbeat extends `lease_expires_at` every N seconds.

### Ack success
Update job: status = `succeeded`, finished_at = now(), clear locked_*. Insert event `succeeded`.

### Fail / retry
On exception: increment attempt, record error fields. If attempt < max_attempts: set status = queued, run_at = now() + backoff(attempt), clear locks, insert event `retried`. Else: set status = failed, finished_at = now(), clear locks, insert event `failed`.

### Sweep stale running jobs
Command `phoenixqueue sweep`: find `running` where `lease_expires_at < now()`, mark them `interrupted`, clear lock fields, insert event `interrupted`. Optional flag `--requeue` moves interrupted back to queued.

---

## ActiveJob integration

Implement `ActiveJob::QueueAdapters::PhoenixqueueAdapter`:

- **enqueue(job):** insert into `phoenixqueue_jobs` with payload = `job.serialize`, queue = `job.queue_name`, run_at = now, status = queued; insert event `enqueued`.
- **enqueue_at(job, timestamp):** same as enqueue but run_at = timestamp.

Worker execution: load payload, call `ActiveJob::Base.execute(payload)`, ensure Rails autoloading (railtie/engine).

---

## Checkpoint DSL

Provide module `Phoenixqueue::Checkpointed` for jobs.

### API
- `step(name, metadata: {}) { ... }`
- `steps_completed` (array)
- `current_step` (string/nil)

### Storage in `jobs.progress` (jsonb)

Example:

```json
{
  "completed": ["plan", "drain"],
  "current": "upgrade",
  "meta": {
    "drain": { "nodes": ["n1", "n2"] }
  }
}
```

### Behavior
- On entering a step: set `current` to step name; optionally emit `job_event(checkpoint)` for step start.
- On step success: add to `completed`, clear `current`, emit `job_event(checkpoint)` for completion.
- On resume/retry: if step in `completed`, skip executing block.

### Execution context
Checkpoint code must know which `phoenixqueue_job` row corresponds to the running ActiveJob. Implement `Phoenixqueue::Current` (thread-local, cleared in ensure) with `job_id` and optional `job_record`. Set it in the worker wrapper around `ActiveJob::Base.execute(payload)`.

---

## Web UI

Build a Rails Engine `Phoenixqueue::Web` mountable in the host app.

### Routes (minimum)
- `GET /phoenixqueue` — dashboard
- `GET /phoenixqueue/jobs` — jobs index with filters
- `GET /phoenixqueue/jobs/:id` — job detail
- `POST /phoenixqueue/jobs/:id/retry`
- `POST /phoenixqueue/jobs/:id/resume` (alias of retry, preserves checkpoints)
- `POST /phoenixqueue/jobs/:id/cancel`

### Dashboard
- Counts by status (queued, running, failed, interrupted, succeeded)
- Queue latency (oldest queued job age per queue)
- Top failing job_class in last 24h
- Currently running jobs (top N) with duration

### Job list filters
- status (single-select), queue, job_class (string match), time window (last 1h/24h/7d), optional "actionable" (failed + interrupted)

### Job detail
- Payload (redacted / collapsed by default), timestamps (enqueued, run_at, started, finished), last error (class, message, backtrace), attempts/max_attempts, progress (completed steps + current), event timeline from `phoenixqueue_job_events`

### Security / PII
`Phoenixqueue.config.redact_keys = [...]`; redact those keys in UI payload display.

---

## Repo scaffolding

- `./bin/setup`: install deps, start Postgres via docker compose, prepare db
- `./bin/test`: db up + migrations + rspec
- `docker-compose.yml` with `postgres` service; env vars `PHOENIXQUEUE_DATABASE_URL` and `PHOENIXQUEUE_TEST_DATABASE_URL` (default to local docker compose URLs if unset)

---

## Implementation order

1. Scaffold gem + test harness + docker Postgres
2. Add migrations + models + basic event logging
3. Implement claim/execute/ack/fail with SKIP LOCKED
4. Add ActiveJob adapter + railtie
5. Add checkpoint DSL + tests
6. Add Web UI engine + request specs
7. Add sweep command + tests
8. Polish docs + examples

---

## Success criteria (Ralph checkboxes)

### Phase 0 — scaffolding
1. [x] Repo root is a Ruby gem named `phoenixqueue` with `phoenixqueue.gemspec`, `Gemfile`, and `lib/phoenixqueue.rb`.
2. [x] RSpec is configured and `bundle exec rspec` runs (even if only a placeholder spec).
3. [x] `docker-compose.yml` exists and can start Postgres (`docker compose up -d`).
4. [x] `./bin/setup` exists and completes successfully with Docker installed.
5. [x] `./bin/test` exists and runs the full suite (db up + migrations + tests) and exits 0.

### Phase 1 — persistence & models
6. [x] Rails engine or railtie loads `Phoenixqueue::Job` and `Phoenixqueue::JobEvent`.
7. [x] Migrations create `phoenixqueue_jobs` and `phoenixqueue_job_events` with required columns and indexes.
8. [x] `Phoenixqueue::Job` validates required fields (queue, job_class, payload, status, run_at).
9. [x] Creating a job record automatically writes `job_event(enqueued)`.

### Phase 2 — worker core
10. [x] Worker implements `claim_next_job(queues:, worker_id:)` using `FOR UPDATE SKIP LOCKED`.
11. [x] Worker updates job to `running` with `locked_by`, `locked_at`, `lease_expires_at`.
12. [x] Worker executes a claimed job via `ActiveJob::Base.execute(payload)`.
13. [x] On success: job becomes `succeeded` with `finished_at` and `job_event(succeeded)`.
14. [x] On exception: record error; retry (re-queue with backoff) or set `failed` when `max_attempts` exceeded.
15. [x] Heartbeat updates `lease_expires_at` while job is running (configurable interval + lease duration).

### Phase 3 — sweeper / interruption
16. [x] Command `phoenixqueue sweep` exists and marks stale running jobs as `interrupted`.
17. [x] Sweeper writes `job_event(interrupted)` when marking a job interrupted.
18. [x] Optional: `phoenixqueue sweep --requeue` requeues interrupted jobs to `queued` (and writes `job_event(retried)` or `requeued`).

### Phase 4 — ActiveJob adapter
19. [x] `ActiveJob::QueueAdapters::PhoenixqueueAdapter` exists with `enqueue` and `enqueue_at`.
20. [x] Dummy Rails app in `spec/dummy` can set `config.active_job.queue_adapter = :phoenixqueue` and enqueue a job.
21. [x] RSpec: enqueuing via ActiveJob creates a `phoenixqueue_jobs` row with correct queue, job_class, payload, run_at.

### Phase 5 — checkpoint/resume DSL
22. [x] Module `Phoenixqueue::Checkpointed` provides `step(:name) { ... }`.
23. [x] Worker sets `Phoenixqueue::Current.job_id` (thread-local) during execution and clears it in `ensure`.
24. [x] Completed steps are persisted in `jobs.progress` jsonb.
25. [x] On retry/resume, completed steps are skipped (verified by specs).
26. [x] If a job fails mid-step, that step is not marked complete and re-runs on retry (verified by specs).

### Phase 6 — Web UI (Rails engine)
27. [x] Rails engine `Phoenixqueue::Web` is mountable (document route mount in README).
28. [x] `GET /phoenixqueue` dashboard returns 200 and shows counts by status + queue latency.
29. [x] `GET /phoenixqueue/jobs` returns 200 and supports filtering by status, queue, job_class.
30. [x] `GET /phoenixqueue/jobs/:id` returns 200 and shows payload, error, attempts, timing, progress steps.
31. [x] `POST /phoenixqueue/jobs/:id/retry` works (job back to queued, attempt incremented as appropriate).
32. [ ] `POST /phoenixqueue/jobs/:id/resume` works and preserves checkpoint progress (skips completed steps).
33. [ ] `POST /phoenixqueue/jobs/:id/cancel` marks job `canceled` and prevents further execution.

### Phase 7 — UX/security polish
34. [ ] Payload redaction via `Phoenixqueue.config.redact_keys`; UI displays redacted payload fields.
35. [ ] README explains at-least-once, interruption handling, checkpoint limitations, and how to run worker + UI.
36. [ ] `./bin/test` is green and sufficient to claim task complete.

---

## Ralph instructions

- Work in small commits. Prefer 1–3 checkboxes per iteration.
- Always keep `./bin/test` working. If you break it, fix it before continuing.
- Update checkboxes to `[x]` only when the criterion is done and covered by tests where feasible.
- Avoid broad refactors unless necessary for a checkbox.
- When everything is complete and `./bin/test` passes, end output with `<ralph>COMPLETE</ralph>`.
- If stuck (repeated failures, no progress after 3 attempts), write a short note in `.ralph/guardrails.md` and end output with `<ralph>GUTTER</ralph>`.
