module Phoenixqueue
  module Redaction
    REDACTED = "[REDACTED]".freeze

    def self.redact(value, keys:)
      key_set = Array(keys).map { |k| k.to_s.downcase }.to_h { |k| [k, true] }
      redact_value(value, key_set)
    end

    def self.redact_value(value, key_set) # rubocop:disable Naming/AccessorMethodName
      case value
      when Hash
        value.each_with_object({}) do |(k, v), acc|
          if key_set[k.to_s.downcase]
            acc[k] = REDACTED
          else
            acc[k] = redact_value(v, key_set)
          end
        end
      when Array
        value.map { |v| redact_value(v, key_set) }
      else
        value
      end
    end

    private_class_method :redact_value
  end
end

