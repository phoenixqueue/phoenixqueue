class CreatePhoenixqueueJobEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :phoenixqueue_job_events do |t|
      t.bigint :job_id, null: false
      t.string :event_type, null: false
      t.jsonb :data, null: false, default: {}
      t.column :created_at, :timestamptz, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_foreign_key :phoenixqueue_job_events, :phoenixqueue_jobs, column: :job_id
    add_index :phoenixqueue_job_events, [:job_id, :id], name: "index_phoenixqueue_job_events_job_id_id"
  end
end

