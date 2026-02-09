Dummy::Application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.secret_key_base = "phoenixqueue_dummy_secret_key_base"

  config.active_job.queue_adapter = :phoenixqueue
end

