class CreatePhoenixqueueJobs < ActiveRecord::Migration[6.1]
  def change
    create_table :phoenixqueue_jobs do |t|
      t.string :queue, null: false, default: "default"
      t.string :job_class, null: false
      t.jsonb :payload, null: false
      t.string :status, null: false
      t.integer :priority, null: false, default: 0
      t.column :run_at, :timestamptz, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.integer :attempt, null: false, default: 0
      t.integer :max_attempts, null: false, default: 25
      t.string :locked_by
      t.column :locked_at, :timestamptz
      t.column :lease_expires_at, :timestamptz
      t.column :started_at, :timestamptz
      t.column :finished_at, :timestamptz
      t.string :last_error_class
      t.text :last_error_message
      t.text :last_error_backtrace
      t.jsonb :progress, null: false, default: {}

      t.timestamps
    end

    add_index :phoenixqueue_jobs, [:status, :run_at, :priority, :id], name: "index_phoenixqueue_jobs_claiming"
    add_index :phoenixqueue_jobs, [:queue, :status, :run_at], name: "index_phoenixqueue_jobs_queue_status_run_at"
    add_index :phoenixqueue_jobs, [:job_class, :status, :created_at], name: "index_phoenixqueue_jobs_job_class_status_created_at"
  end
end

