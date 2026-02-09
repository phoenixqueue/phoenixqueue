module Phoenixqueue
  class Config
    attr_accessor :redact_keys

    def initialize
      @redact_keys = []
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end
end

