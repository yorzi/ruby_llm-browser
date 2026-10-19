# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # The host callback failed after browser execution and cleanup were attempted.
      # Retain these values in host storage to retry delivery without rerunning a job.
      # These are in-process objects, not a durable queue or automatic retry policy.
      class ResultDeliveryError < Error
        CODE = "RESULT_DELIVERY_FAILED"

        attr_reader :operation, :result

        def initialize(operation:, result:)
          @operation = operation
          @result = result
          super("host result delivery failed; retry delivery without repeating browser work")
        end
      end
    end
  end
end
