# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Durable, multi-worker {RubyLLM::Browser::OperationStore} backed by ActiveRecord.
      #
      # This is the production store for the optional adapter. Every mutating method runs
      # inside a transaction that locks the affected rows, so:
      #
      # - a duplicate reservation loses the unique-index race and is reported as
      #   {InvalidInput} instead of silently starting a second session
      # - a duplicated worker that re-leases an operation bumps its fence, and any
      #   earlier writer is then refused as stale (fenced out)
      # - a cancelled operation keeps its row and reservation until closure/expiry is
      #   proven; cancellation fences stale workers by bumping the fence
      #
      # The store never interprets provider truth: it records the states the engine and
      # reaper report.
      class ActiveRecordOperationStore < OperationStore
        def initialize(record_class: OperationRecord)
          super()
          @record_class = record_class
        end

        def reserve(operation)
          @record_class.transaction do
            lock_open_for(operation.actor_id)
            if @record_class.exists?(operation.id)
              raise InvalidInput, "operation #{operation.id} is already reserved"
            end

            enforce_concurrency!(operation)
            insert!(operation)
          end
        rescue ActiveRecord::RecordNotUnique
          raise InvalidInput, "operation #{operation.id} is already reserved"
        end

        def attach_or_reserve(operation)
          existing = find_by_idempotency_key(operation.actor_id, operation.run_id, operation.idempotency_key)
          return existing.to_operation if existing

          reserve(operation)
        rescue ActiveRecord::RecordNotUnique
          record = find_by_idempotency_key(operation.actor_id, operation.run_id, operation.idempotency_key)
          raise unless record

          record.to_operation
        end

        def fetch(id)
          @record_class.find_by(id: id)&.to_operation
        end

        def fetch!(id)
          fetch(id) || raise(InvalidInput, "unknown operation #{id.inspect}")
        end

        # Claims the operation for one worker by bumping its fence token.
        def lease(id, actor_id:, run_id:, now:)
          @record_class.transaction do
            record = locked!(id)
            assert_actor!(record, actor_id, run_id)
            if record.to_operation.terminal?
              raise InvalidInput, "operation #{id} is already #{record.state}"
            end

            leased = record.to_operation.with_fence(record.fence + 1, now: now)
            persist!(record, leased)
          end
        end

        # Persists +operation+ only when its fence is current.
        def update(operation)
          @record_class.transaction do
            record = locked!(operation.id)
            if operation.fence < record.fence
              raise InvalidInput, "stale operation writer (fenced at #{record.fence})"
            end
            if record.state.to_sym == :cancelled && operation.state.to_sym != :cancelled
              raise InvalidInput, "operation #{operation.id} was cancelled (fenced at #{record.fence})"
            end

            persist!(record, operation)
          end
        end

        def mark_cleanup_pending(id, actor_id:, run_id:, error_code: nil, now:)
          @record_class.transaction do
            record = locked!(id)
            assert_actor!(record, actor_id, run_id)
            updated = record.to_operation.advance(:cleanup_pending, now: now, error_code: error_code)
            persist!(record, updated)
          end
        end

        # Host-initiated cancellation. Marks the operation and fences stale workers.
        #
        # @return [Operation] the cancelled (or already terminal) operation
        def cancel(id, actor_id:, run_id:, now:)
          @record_class.transaction do
            record = locked!(id)
            assert_actor!(record, actor_id, run_id)
            current = record.to_operation
            return current if current.terminal?

            cancelled = current.with_fence(record.fence + 1, now: now).advance(:cancelled, now: now)
            persist!(record, cancelled)
          end
        end

        def open_for(actor_id)
          @record_class.where(actor_id: actor_id).where(state: open_states).order(:created_at).map(&:to_operation)
        end

        def open_operations
          @record_class.where(state: open_states).order(:created_at).map(&:to_operation)
        end

        # Finds an existing operation by its actor/run idempotency key.
        def find_by_idempotency_key(actor_id, run_id, key)
          return nil if key.nil?

          @record_class.find_by(actor_id: actor_id, run_id: run_id, idempotency_key: key)
        end

        private

        def locked!(id)
          @record_class.lock.find_by(id: id) || raise(InvalidInput, "unknown operation #{id.inspect}")
        end

        def open_states = Operation::OPEN_STATES.map(&:to_s)

        # Locks the actor's open rows so two concurrent reservations cannot both pass the
        # concurrency check on a database with row locks (PostgreSQL, MySQL).
        def lock_open_for(actor_id)
          @record_class.where(actor_id: actor_id).where(state: open_states).lock.to_a
        end

        def enforce_concurrency!(operation)
          open = @record_class.where(actor_id: operation.actor_id).where(state: open_states).count
          return if open < operation.budget.max_concurrent

          raise BudgetExhausted,
                "actor #{operation.actor_id.inspect} already holds #{open} open browser operation(s)"
        end

        def assert_actor!(record, actor_id, run_id)
          return if record.actor_id == actor_id && record.run_id == run_id

          raise NotAuthorized, "operation #{record.id} belongs to a different actor or run"
        end

        def insert!(operation)
          record = @record_class.new(id: operation.id)
          persist!(record, operation)
        end

        def persist!(record, operation)
          record.actor_id = operation.actor_id
          record.run_id = operation.run_id
          record.state = operation.state.to_s
          record.session_id = operation.session_id
          record.idempotency_key = operation.idempotency_key
          record.steps = operation.steps
          record.bytes = operation.bytes
          record.fence = operation.fence
          record.error_code = operation.error_code
          record.budget = @record_class.dump_budget(operation.budget)
          record.created_at = operation.created_at
          record.updated_at = operation.updated_at
          record.save!
          operation
        end
      end
    end
  end
end
