require "active_record"
require "logger"

module Phoenixqueue
  module TestDatabase
    def self.database_url
      ENV.fetch("PHOENIXQUEUE_TEST_DATABASE_URL", "postgres://phoenixqueue:phoenixqueue@localhost:54324/phoenixqueue_test")
    end

    def self.connect!
      ActiveRecord::Base.establish_connection(database_url)
      ActiveRecord::Base.logger = Logger.new($stdout) if ENV["AR_DEBUG"]
    end

    def self.migrate!
      migrations_path = File.expand_path("../../db/migrate", __dir__)
      ActiveRecord::Migration.verbose = false
      ActiveRecord::MigrationContext.new(migrations_path, ActiveRecord::SchemaMigration).migrate
    end

    def self.clean!
      conn = ActiveRecord::Base.connection
      return unless conn.data_source_exists?("phoenixqueue_jobs") && conn.data_source_exists?("phoenixqueue_job_events")

      Phoenixqueue::JobEvent.delete_all
      Phoenixqueue::Job.delete_all
    end
  end
end

