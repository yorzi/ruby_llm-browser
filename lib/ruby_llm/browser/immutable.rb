# frozen_string_literal: true

module RubyLLM
  module Browser
    # Copies host-owned input before freezing it. Never freezes the caller's objects.
    module Immutable
      module_function

      def copy(value)
        case value
        when Hash then value.to_h { |key, nested| [ copy(key), copy(nested) ] }.freeze
        when Array then value.map { |nested| copy(nested) }.freeze
        when String, Time then value.dup.freeze
        else value
        end
      end
    end
  end
end
