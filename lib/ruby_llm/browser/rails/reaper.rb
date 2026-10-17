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
          return close(operation, now) if never_started?(operation)

          case @backend.reconcile(operation, now: now)
          when :closed then close(operation, now)
          when :cleanup_pending then mark_cleanup_pending(operation, now)
          when :active then close_remote?(operation, now) ? close(operation, now) : mark_cleanup_pending(operation, now)
          else :unknown
          end
        end

        def reapable?(operation, now)
          operation.expired?(now) || idle?(operation, now)
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
        rescue Error
          false
        end

        def close(operation, now)
          write(operation, :closed, now)
          :closed
        end

        def mark_cleanup_pending(operation, now)
          write(operation, :cleanup_pending, now, error_code: CleanupPending.code)
          :cleanup_pending
        end

        def write(operation, target, now, error_code: :keep)
          fenced = operation.with_fence(operation.fence + 1, now: now)
          @store.update(fenced.advance(target, now: now, error_code: error_code))
        rescue Error => e
          @logger&.warn { "browser reaper could not update #{operation.id}: #{e.message}" }
          nil
        end
      end
    end
  end
end
