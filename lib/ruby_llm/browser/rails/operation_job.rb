# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Active Job wrapper for one bounded browser operation.
      #
      # The job is deliberately *not* a scheduler: it never reserves a second operation
      # and never retries an effectful call. The host reserves (or attaches to) a durable
      # operation with {.enqueue} and this job attaches to that exact row. On delivery it
      # leases the row (bumping its fence), refuses the wrong actor or an already-terminal
      # operation, and runs the read-only operation through the {Engine}. A duplicated or
      # resumed delivery finds a non-`:reserved` row and returns without a remote call; a
      # worker that lost the lease is refused as stale.
      #
      # The context (backend, source policy, stores, budget, consent) is host-supplied and
      # cannot be serialized, so the job builds it from a configured factory:
      #
      #   RubyLLM::Browser::Rails.context_factory = lambda do |actor_id:, run_id:|
      #     RubyLLM::Browser::Context.new(
      #       actor_id: actor_id, run_id: run_id, backend: qualified_backend,
      #       source_policy: host_policy, operation_store: RubyLLM::Browser::Rails.operation_store
      #     )
      #   end
      class OperationJob < ActiveJob::Base
        # Do not write URLs, instructions or host-pinned schemas into Active Job logs.
        self.log_arguments = false
        class << self
          # ->(actor_id:, run_id:) { RubyLLM::Browser::Context }
          attr_accessor :context_factory

          # Overrides the module store for this job class. Defaults to the module store.
          attr_accessor :operation_store

          # Reserves (or attaches to) the durable operation for +idempotency_key+ and
          # enqueues exactly one job for it. A second call with the same key attaches to
          # the same operation instead of reserving a new one.
          #
          # @return [Operation] the reserved or attached operation
          def enqueue(actor_id:, run_id:, kind:, url:, budget:, idempotency_key: nil,
                      instruction: nil, schema: nil, max_bytes: nil, store: nil, now: nil)
            configured_store = operation_store || RubyLLM::Browser::Rails.operation_store
            store ||= configured_store
            raise InvalidInput, "enqueue must use the job's operation store" unless store.equal?(configured_store)
            now ||= RubyLLM::Browser::Rails.clock.call
            unless %w[inspect extract].include?(kind.to_s)
              raise InvalidInput, "browser jobs support inspect and extract only"
            end
            candidate = Operation.new(
              id: Operation.generate_id, actor_id: actor_id, run_id: run_id, budget: budget,
              state: :reserved, idempotency_key: idempotency_key, created_at: now, updated_at: now,
              request_digest: request_digest(kind: kind, url: url, instruction: instruction,
                                             schema: schema, max_bytes: max_bytes, budget: budget)
            )
            operation = store.attach_or_reserve(candidate)
            perform_later(
              operation_id: operation.id, actor_id: actor_id, run_id: run_id, kind: kind.to_s,
              url: url, instruction: instruction, schema: schema, max_bytes: max_bytes
            )
            operation
          end

          # Binds an idempotency key to the exact host-issued payload and budget.
          def request_digest(kind:, url:, instruction:, schema:, max_bytes:, budget:)
            Redactor.digest(kind: kind.to_s, url: url, instruction: instruction, schema: schema,
                            max_bytes: max_bytes, budget: budget.to_h)
          end
        end

        queue_as { RubyLLM::Browser::Rails.job_queue }

        def perform(operation_id:, actor_id:, run_id:, kind:, url:, instruction: nil,
                    schema: nil, max_bytes: nil)
          operation = store.fetch(operation_id)
          return :missing if operation.nil?

          assert_scope!(operation, actor_id, run_id)
          digest = self.class.request_digest(kind: kind, url: url, instruction: instruction,
                                             schema: schema, max_bytes: max_bytes, budget: operation.budget)
          if operation.request_digest && operation.request_digest != digest
            raise NotAuthorized, "job payload does not match the reserved request"
          end
          return :cancelled if operation.state == :cancelled
          return :terminal if operation.terminal?
          return :attached unless operation.state == :reserved

          leased = store.lease(operation_id, actor_id: actor_id, run_id: run_id, now: now)
          return :cancelled if leased.state == :cancelled

          result = run(kind, leased, url: url, instruction: instruction, schema: schema,
                                     max_bytes: max_bytes)

          # Keep unknown action/start results, even when cleanup later closes a session.
          final = settled(operation_id)
          return :cancelled if final == :cancelled

          result.ok? ? (final || result.to_h) : result.to_h
        rescue InvalidInput => e
          raise unless fenced?(e)

          :fenced_out
        end

        private

        # Reports the durable state if the host cancelled or another worker fenced this
        # one while the operation was running; otherwise returns nil so the engine's own
        # result is used.
        def settled(operation_id)
          final = store.fetch(operation_id)
          case final&.state
          when :cancelled then :cancelled
          when :cleanup_pending then :cleanup_pending
          when :unknown then :unknown
          end
        end

        def run(kind, operation, url:, instruction:, schema:, max_bytes:)
          context = build_context(operation)
          unless context.is_a?(Context) && context.operation_store.equal?(store)
            raise InvalidInput, "job context must use the job's operation store"
          end
          engine = Engine.new(context: context)
          case kind.to_s
          when "inspect"
            engine.inspect(url: url, instruction: instruction, max_bytes: max_bytes, operation: operation)
          when "extract"
            engine.extract(url: url, schema: schema, instruction: instruction,
                                       max_bytes: max_bytes, operation: operation)
          else
            raise InvalidInput, "unknown browser operation kind #{kind.inspect}"
          end
        end

        def build_context(operation)
          factory = self.class.context_factory || RubyLLM::Browser::Rails.context_factory
          raise InvalidInput, "no RubyLLM::Browser context factory is configured" if factory.nil?

          factory.call(actor_id: operation.actor_id, run_id: operation.run_id)
        end

        def assert_scope!(operation, actor_id, run_id)
          return if operation.actor_id == actor_id && operation.run_id == run_id

          raise NotAuthorized, "operation #{operation.id} belongs to a different actor or run"
        end

        def fenced?(error)
          error.message.include?("stale") || error.message.include?("fenced") ||
            error.message.include?("cancelled")
        end

        def store
          self.class.operation_store || RubyLLM::Browser::Rails.operation_store
        end

        def now
          RubyLLM::Browser::Rails.clock.call
        end
      end
    end
  end
end
