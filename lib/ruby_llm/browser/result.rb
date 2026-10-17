# frozen_string_literal: true

require "json"
require "time"

module RubyLLM
  module Browser
    # Bounded, sanitized output of a browser operation, with provenance.
    #
    # A Result is untrusted evidence with provenance: it records where content came from
    # and when, but an `ok` status never verifies that an extracted claim is true. It
    # never carries API keys, cookies, provider session IDs, `cdp_url` values, raw page
    # dumps or screenshots.
    class Result
      # Machine-readable outcome.
      #
      # - `:ok`              completed with confirmed session closure
      # - `:truncated`       completed but content hit a byte/step limit
      # - `:error`           a typed, safe error stopped the operation
      # - `:unknown`         a remote outcome could not be confirmed
      # - `:cleanup_pending` cleanup was attempted but not confirmed
      STATUSES = %i[ok truncated error unknown cleanup_pending].freeze

      attr_reader :status, :operation_id, :final_url, :captured_at, :locator, :digest,
                  :data, :error_code, :error_message

      def initialize(status:, operation_id: nil, final_url: nil, captured_at: nil, locator: nil,
                     digest: nil, data: nil, truncated: false, error_code: nil, error_message: nil)
        @status = normalize_status(status)
        @operation_id = operation_id
        @final_url = final_url
        @captured_at = captured_at
        @locator = locator
        @digest = digest
        @data = data
        @truncated = truncated ? true : false
        @error_code = error_code
        @error_message = error_message
        freeze
      end

      # A successful result. `truncated:` marks a bounded-but-complete outcome.
      def self.ok(data: nil, operation_id: nil, final_url: nil, captured_at: nil, locator: nil,
                  digest: nil, truncated: false)
        new(status: truncated ? :truncated : :ok, data: data, operation_id: operation_id,
            final_url: final_url, captured_at: captured_at, locator: locator, digest: digest,
            truncated: truncated)
      end

      # A typed failure. Used for `error`, `unknown` and `cleanup_pending` outcomes.
      def self.failure(status, error_code:, message:, operation_id: nil, final_url: nil,
                       captured_at: nil, data: nil)
        new(status: status, error_code: error_code, error_message: message,
            operation_id: operation_id, final_url: final_url, captured_at: captured_at, data: data)
      end

      def truncated? = @truncated
      def ok? = status == :ok || status == :truncated

      # A model-safe Hash. Times are ISO 8601 UTC strings.
      def to_h
        {
          status: status.to_s,
          operation_id: operation_id,
          final_url: final_url,
          captured_at: captured_at&.utc&.iso8601,
          locator: locator,
          digest: digest,
          truncated: @truncated,
          data: data,
          error: error_code ? { code: error_code.to_s, message: error_message } : nil
        }.compact
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      def deconstruct_keys(_keys)
        to_h
      end

      def ==(other)
        other.is_a?(Result) && to_h == other.to_h
      end
      alias eql? ==

      def inspect
        "#<#{self.class} status=#{status} operation_id=#{operation_id.inspect} url=#{final_url.inspect}>"
      end

      private

      def normalize_status(status)
        status = status.to_sym
        return status if STATUSES.include?(status)

        raise InvalidInput, "unknown result status: #{status.inspect}"
      end
    end
  end
end
