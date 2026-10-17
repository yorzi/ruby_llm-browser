# frozen_string_literal: true

module RubyLLM
  module Browser
    # Immutable limits for a single browser operation.
    #
    # A budget is deliberately conservative. Elapsed time, steps and bytes are separate
    # limits, and a projected or estimated cost is never presented as a provider-enforced
    # hard billing cap. When a limit is unknown or exhausted the Gem refuses more work
    # rather than guessing.
    class Budget
      DEFAULT_MAX_SECONDS = 60
      DEFAULT_MAX_STEPS = 12
      DEFAULT_MAX_BYTES = 262_144 # 256 KiB of page/result bytes
      DEFAULT_MAX_CONCURRENT = 1

      attr_reader :max_seconds, :max_steps, :max_bytes, :max_concurrent, :max_cost_usd

      # @param max_seconds [Numeric] wall-clock ceiling for the operation
      # @param max_steps [Integer] maximum provider round-trips (navigate/observe/...)
      # @param max_bytes [Integer] maximum bytes of page/result content kept per operation
      # @param max_concurrent [Integer] concurrent sessions allowed for the actor
      # @param max_cost_usd [Numeric, nil] advisory cost reservation; nil means unknown
      def initialize(max_seconds: DEFAULT_MAX_SECONDS, max_steps: DEFAULT_MAX_STEPS,
                     max_bytes: DEFAULT_MAX_BYTES, max_concurrent: DEFAULT_MAX_CONCURRENT,
                     max_cost_usd: nil)
        @max_seconds = positive_number!(max_seconds, :max_seconds)
        @max_steps = positive_integer!(max_steps, :max_steps)
        @max_bytes = positive_integer!(max_bytes, :max_bytes)
        @max_concurrent = positive_integer!(max_concurrent, :max_concurrent)
        @max_cost_usd = max_cost_usd.nil? ? nil : non_negative_number!(max_cost_usd, :max_cost_usd)

        freeze
      end

      def to_h
        {
          max_seconds: max_seconds,
          max_steps: max_steps,
          max_bytes: max_bytes,
          max_concurrent: max_concurrent,
          max_cost_usd: max_cost_usd
        }
      end

      def digest
        Redactor.digest(to_h)
      end

      def ==(other)
        other.is_a?(Budget) && to_h == other.to_h
      end
      alias eql? ==

      def hash
        to_h.hash
      end

      def inspect
        "#<#{self.class} seconds=#{max_seconds} steps=#{max_steps} bytes=#{max_bytes} concurrent=#{max_concurrent}>"
      end

      private

      def positive_number!(value, name)
        unless value.is_a?(Numeric) && value.positive?
          raise InvalidInput, "#{name} must be a positive number"
        end

        value
      end

      def non_negative_number!(value, name)
        unless value.is_a?(Numeric) && value >= 0
          raise InvalidInput, "#{name} must be a non-negative number"
        end

        value
      end

      def positive_integer!(value, name)
        unless value.is_a?(Integer) && value.positive?
          raise InvalidInput, "#{name} must be a positive integer"
        end

        value
      end
    end
  end
end
