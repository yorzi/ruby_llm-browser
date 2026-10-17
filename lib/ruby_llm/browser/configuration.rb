# frozen_string_literal: true

require "logger"

module RubyLLM
  module Browser
    # Process-wide defaults. Per-call behaviour belongs on {Context}, {Policy} and the
    # backend; this object only holds values that are safe to share.
    #
    # Requiring the Gem never reads credentials or environment variables; configuration
    # is explicit.
    class Configuration
      DEFAULT_MAX_RESULT_BYTES = 65_536 # 64 KiB of sanitized result data

      # A default backend for tools that share one. Optional: {Context} carries its own.
      attr_accessor :backend

      attr_reader :clock, :default_budget, :max_result_bytes

      def initialize
        @backend = nil
        @logger = nil
        @clock = -> { Time.now.utc }
        @default_budget = Budget.new
        @max_result_bytes = DEFAULT_MAX_RESULT_BYTES
      end

      # The logger used for audit lines. Falls back to RubyLLM's logger when present.
      def logger
        @logger || default_logger
      end

      attr_writer :logger

      def clock=(callable)
        unless callable.respond_to?(:call)
          raise InvalidInput, "clock must respond to #call and return a Time"
        end

        @clock = callable
      end

      def default_budget=(budget)
        raise InvalidInput, "default_budget must be a RubyLLM::Browser::Budget" unless budget.is_a?(Budget)

        @default_budget = budget
      end

      def max_result_bytes=(value)
        unless value.is_a?(Integer) && value.positive?
          raise InvalidInput, "max_result_bytes must be a positive integer"
        end

        @max_result_bytes = value
      end

      # Current UTC time from the configured clock.
      def now
        clock.call
      end

      private

      def default_logger
        if defined?(RubyLLM) && RubyLLM.respond_to?(:logger) && RubyLLM.logger
          RubyLLM.logger
        else
          Logger.new($stderr, level: Logger::WARN)
        end
      end
    end
  end
end
