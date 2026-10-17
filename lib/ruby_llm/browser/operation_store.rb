# frozen_string_literal: true

module RubyLLM
  module Browser
    # Durable bookkeeping for browser operations.
    #
    # The host supplies an implementation. {InMemoryOperationStore} is a fixture for
    # tests and single-process demos only; production multi-worker or restart-safe use
    # requires a durable store (for example the ActiveRecord store in
    # `ruby_llm/browser/rails`).
    #
    # Every method is expected to be atomic. Callers assume:
    #
    # - {#reserve} never starts two operations for one idempotency key
    # - {#update} rejects a stale writer (fencing)
    # - the reservation is held for `unknown` / `cleanup_pending`, not released early
    class OperationStore
      # Atomically stores a new operation and enforces the actor's concurrency budget.
      # @raise [InvalidInput] the id already exists
      # @raise [BudgetExhausted] the concurrency slot is taken
      def reserve(_operation)
        raise NotImplementedError, "OperationStore#reserve must be implemented"
      end

      # Returns the existing operation for the same actor/run/idempotency key, or
      # reserves +operation+. Duplicate jobs must attach, never start a second session.
      def attach_or_reserve(_operation)
        raise NotImplementedError, "OperationStore#attach_or_reserve must be implemented"
      end

      # @return [Operation, nil]
      def fetch(_id)
        raise NotImplementedError, "OperationStore#fetch must be implemented"
      end

      # Returns the operation or raises {InvalidInput} when absent.
      def fetch!(_id)
        raise NotImplementedError, "OperationStore#fetch! must be implemented"
      end

      # Claims the operation for one worker, bumping its fence token.
      #
      # @return [Operation] the newly leased operation
      # @raise [NotAuthorized] a different actor/run tries to claim it
      def lease(_id, actor_id:, run_id:, now:)
        raise NotImplementedError, "OperationStore#lease must be implemented"
      end

      # Persists +operation+ only if its fence is current.
      #
      # @return [Operation] the stored operation
      # @raise [InvalidInput] the writer is fenced (stale)
      def update(_operation)
        raise NotImplementedError, "OperationStore#update must be implemented"
      end

      # Marks an operation unable to confirm its own cleanup.
      #
      # @return [Operation]
      def mark_cleanup_pending(_id, actor_id:, run_id:, error_code: nil, now:)
        raise NotImplementedError, "OperationStore#mark_cleanup_pending must be implemented"
      end

      # @return [Array<Operation>] operations currently holding a slot for the actor
      def open_for(_actor_id)
        raise NotImplementedError, "OperationStore#open_for must be implemented"
      end
    end
  end
end
