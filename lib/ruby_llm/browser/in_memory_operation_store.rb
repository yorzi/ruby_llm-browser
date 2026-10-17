# frozen_string_literal: true

module RubyLLM
  module Browser
    # Thread-safe, in-process {OperationStore}.
    #
    # This is a fixture for tests and single-process demos. It is **not** production
    # ready: state disappears on restart and cannot synchronize across workers or
    # hosts. Use a durable store for anything long-running.
    class InMemoryOperationStore < OperationStore
      def initialize(clock: nil)
        super()
        @mutex = Mutex.new
        @operations = {}
        @clock = clock
      end

      def reserve(operation)
        synchronize do
          if @operations.key?(operation.id)
            raise InvalidInput, "operation #{operation.id} is already reserved"
          end

          enforce_concurrency!(operation)
          @operations[operation.id] = operation
        end
      end

      def attach_or_reserve(operation)
        synchronize do
          existing = find_by_idempotency_key(operation.actor_id, operation.run_id, operation.idempotency_key)
          return existing if existing

          reserve_locked(operation)
        end
      end

      def fetch(id)
        synchronize { @operations[id] }
      end

      def fetch!(id)
        fetch(id) || raise(InvalidInput, "unknown operation #{id.inspect}")
      end

      def lease(id, actor_id:, run_id:, now:)
        synchronize do
          operation = @operations.fetch(id) { raise InvalidInput, "unknown operation #{id.inspect}" }
          assert_actor!(operation, actor_id, run_id)
          if operation.terminal?
            raise InvalidInput, "operation #{id} is already #{operation.state}"
          end

          leased = operation.with_fence(operation.fence + 1, now: now)
          @operations[id] = leased
        end
      end

      def update(operation)
        synchronize do
          stored = @operations.fetch(operation.id) { raise InvalidInput, "unknown operation #{operation.id.inspect}" }
          if operation.fence < stored.fence
            raise InvalidInput, "stale operation writer (fenced at #{stored.fence})"
          end

          @operations[operation.id] = operation
        end
      end

      def mark_cleanup_pending(id, actor_id:, run_id:, error_code: nil, now:)
        synchronize do
          operation = @operations.fetch(id) { raise InvalidInput, "unknown operation #{id.inspect}" }
          assert_actor!(operation, actor_id, run_id)
          updated = operation.advance(:cleanup_pending, now: now, error_code: error_code)
          @operations[id] = updated
        end
      end

      def open_for(actor_id)
        synchronize { @operations.values.select { |operation| operation.actor_id == actor_id && operation.open? } }
      end

      # Snapshot for tests and diagnostics.
      def all
        synchronize { @operations.values.dup }
      end

      private

      def synchronize(&block)
        @mutex.synchronize(&block)
      end

      def reserve_locked(operation)
        if @operations.key?(operation.id)
          raise InvalidInput, "operation #{operation.id} is already reserved"
        end

        enforce_concurrency!(operation)
        @operations[operation.id] = operation
      end

      def find_by_idempotency_key(actor_id, run_id, key)
        return nil if key.nil?

        @operations.values.find do |operation|
          operation.actor_id == actor_id && operation.run_id == run_id && operation.idempotency_key == key
        end
      end

      def enforce_concurrency!(operation)
        open = @operations.values.count { |existing| existing.actor_id == operation.actor_id && existing.open? }
        return if open < operation.budget.max_concurrent

        raise BudgetExhausted,
              "actor #{operation.actor_id.inspect} already holds #{open} open browser operation(s)"
      end

      def assert_actor!(operation, actor_id, run_id)
        return if operation.actor_id == actor_id && operation.run_id == run_id

        raise NotAuthorized, "operation #{operation.id} belongs to a different actor or run"
      end
    end
  end
end
