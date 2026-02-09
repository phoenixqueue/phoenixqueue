require_relative "lib/phoenixqueue/version"

Gem::Specification.new do |spec|
  spec.name = "phoenixqueue"
  spec.version = Phoenixqueue::VERSION
  spec.authors = ["Phoenixqueue contributors"]
  spec.email = ["dev@phoenixqueue.local"]

  spec.summary = "Postgres-backed ActiveJob adapter + worker + checkpoint/resume + Web UI."
  spec.description = "Phoenixqueue is a Postgres-backed background job system with ActiveJob compatibility, checkpoint/resume, and a modern Web UI."
  spec.homepage = "https://github.com/phoenixqueue/phoenixqueue"
  spec.license = "MIT"

  # Task target is Ruby 3.2+, but keep the gemspec compatible with the default
  # macOS system Ruby so `bundle exec rspec` can run in early iterations.
  spec.required_ruby_version = ">= 2.6.0"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0")
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 6.1"
  spec.add_dependency "activejob", "~> 6.1"
  spec.add_dependency "pg"
  spec.add_dependency "railties", "~> 6.1"

  spec.add_development_dependency "rspec"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }
end
