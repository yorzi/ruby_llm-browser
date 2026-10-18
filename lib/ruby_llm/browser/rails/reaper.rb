# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Durable cleanup and reconciliation sweep for the Rails adapter.
      #
      # The reaper is the safety net for operations whose worker died, whose start or end
      # outcome is unknown, or that exceeded their wall-clock budget. It never invents
      # success: it asks the backend to reconcile, attempts a real session close, and
      # leaves `unknown` / `cleanup_pending` visible (with the reservation held) until
      # closure or provider expiry is confirmed.
      #
      #   RubyLLM::Browser::Rails::Reaper.new(backend: qualified_backend).sweep
      #
      # Closing or re-marking an operation bumps its fence, so a surviving worker that
      # resumes after the sweep is refused as stale.
      class Reaper
        # @param backend [RubyLLM::Browser::Backend] used to reconcile and close sessions
        # @param store [RubyLLM::Browser::OperationStore] defaults to the module store
        # @param ttl_seconds [Numeric, nil] optional idle TTL in addition to the budget
        def initialize(backend:, store: nil, clock: nil, logger: nil, ttl_seconds: nil)
          @backend = backend
          @store = store || RubyLLM::Browser::Rails.operation_store
          @clock = clock || RubyLLM::Browser::Rails.clock
          @logger = logger || RubyLLM::Browser.logger
          @ttl_seconds = ttl_seconds
          if ttl_seconds && !(ttl_seconds.is_a?(Numeric) && ttl_seconds.finite? && ttl_seconds.positive?)
            raise InvalidInput, "reaper TTL must be a positive finite number"
          end
        end

        # Sweeps every open operation once.
        #
        # @return [Hash] counts keyed by outcome (`:checked`, `:closed`, `:cleanup_pending`,
        #   `:unknown`, `:kept`) plus `:at`
        def sweep(now: nil)
          time = now || @clock.call
          summary = Hash.new(0)
          @store.open_operations.each do |operation|
            summary[:checked] += 1
            summary[reap(operation, time)] += 1
          end
          summary[:at] = time
          summary
        end

        private

        def reap(operation, now)
          return :kept unless reapable?(operation, now)

          operation = @store.lease(operation.id, actor_id: operation.actor_id,
                                  run_id: operation.run_id, now: now)
          return close(operation, now) if never_started?(operation)

          case @backend.reconcile(operation, now: now)
          when :closed then close(operation, now)
          else
            if operation.session_id
              close_remote?(operation, now) ? close(operation, now) : mark_cleanup_pending(operation, now)
            else
              write(operation, :unknown, now, error_code: SessionUnknown.code)
              :unknown
            end
          end
        rescue StandardError
          @logger&.warn { "browser reaper could not reconcile an operation" }
          :failed
        end

        def reapable?(operation, now)
          operation.cancel_requested? || operation.cleanup_pending? || operation.expired?(now) || idle?(operation, now)
        end

        def idle?(operation, now)
          return false if @ttl_seconds.nil?

          last = operation.updated_at || operation.created_at
          !last.nil? && (now - last) >= @ttl_seconds
        end

        # A reserved operation with no session never reached the provider.
        def never_started?(operation)
          operation.session_id.nil? && operation.state == :reserved
        end

        def close_remote?(operation, now)
          return false if operation.session_id.nil?

          session = Session.new(id: operation.session_id)
          @backend.end_session(session, operation: operation, now: now)
        rescue StandardError
          false
        end

        def close(operation, now)
          if operation.session_id
            @store.confirm_closed(operation, session_id: operation.session_id, now: now)
          else
            write(operation, :closed, now)
          end
          :closed
        end

        def mark_cleanup_pending(operation, now)
          write(operation, :cleanup_pending, now, error_code: CleanupPending.code)
          :cleanup_pending
        end

        def write(operation, target, now, error_code: :keep)
          @store.update(operation.advance(target, now: now, error_code: error_code))
        end
      end
    end
  end
end
