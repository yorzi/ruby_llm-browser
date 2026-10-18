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
          if existing
            raise InvalidInput, "idempotency key belongs to a different request" unless existing.request_digest == operation.request_digest

            return existing
          end

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
          operation.validate_update!(stored)
          @operations[operation.id] = operation
        end
      end

      def claim_start(operation, now:)
        synchronize do
          stored = @operations.fetch(operation.id)
          operation.validate_update!(stored)
          raise InvalidInput, "operation was already started" unless stored.state == :reserved
          raise BudgetExhausted, "operation wall-clock budget exhausted" if stored.expired?(now)

          @operations[operation.id] = stored.advance(:starting, now: now)
        end
      end

      def record_session(operation, session_id:, now:)
        synchronize do
          stored = @operations.fetch(operation.id)
          assert_actor!(stored, operation.actor_id, operation.run_id)
          raise InvalidInput, "operation session cannot change" if stored.session_id && stored.session_id != session_id

          target = stored.fence == operation.fence ? :active : :cleanup_pending
          @operations[operation.id] = stored.advance(target, session_id: session_id, now: now)
        end
      end

      def confirm_closed(operation, session_id:, now:)
        synchronize do
          stored = @operations.fetch(operation.id)
          assert_actor!(stored, operation.actor_id, operation.run_id)
          raise InvalidInput, "operation session cannot change" unless stored.session_id == session_id

          target = stored.cancel_requested? ? :cancelled : :closed
          @operations[operation.id] = stored.advance(target, now: now)
        end
      end

      def cancel(id, actor_id:, run_id:, now:)
        synchronize do
          operation = @operations.fetch(id) { raise InvalidInput, "unknown operation" }
          assert_actor!(operation, actor_id, run_id)
          return operation if operation.terminal? || operation.cancel_requested?

          @operations[id] = operation.with_fence(operation.fence + 1, now: now).request_cancel(now: now)
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

      def open_operations
        synchronize { @operations.values.select(&:open?) }
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
