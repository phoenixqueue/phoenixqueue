ENV["RAILS_ENV"] ||= "test"

require_relative "application"

Dummy::Application.initialize! unless Dummy::Application.initialized?

