# Phoenixqueue

Phoenixqueue is a Postgres-backed background job system with an ActiveJob adapter, a worker, checkpoint/resume, and a Web UI (Rails engine).

## Web UI (Rails engine)

Mount the engine in your Rails app:

```ruby
# config/routes.rb
mount Phoenixqueue::Web::Engine => "/phoenixqueue"
```

Then visit `/phoenixqueue`.

