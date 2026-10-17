# frozen_string_literal: true

require "securerandom"

module RubyLLM
  module Browser
    # Durable identity and lifecycle of one browser operation.
    #
    # An operation is reserved *before* the first remote call and is the anchor for
    # duplicate-job attachment, concurrency, budgets, fencing and cleanup. It never
    # reports an unresolved outcome as success: an ambiguous start or action is
    # +unknown+ and unsuccessful cleanup is +cleanup_pending+, and both keep their
    # budget reservation until closure or expiry is confirmed.
    #
    # Instances are immutable; each transition returns a new operation.
    class Operation
      STATES = %i[reserved starting active closing closed unknown cleanup_pending cancelled].freeze

      # States that keep the reservation open.
      OPEN_STATES = %i[reserved starting active closing unknown cleanup_pending].freeze

      # The only confirmed-finished states.
      TERMINAL_STATES = %i[closed cancelled].freeze

      # Allowed transitions. A state may always advance to itself (refresh/fence bump).
      TRANSITIONS = {
        reserved: %i[starting unknown cleanup_pending closed cancelled],
        starting: %i[active unknown cleanup_pending closed cancelled],
        active: %i[closing unknown cleanup_pending closed cancelled],
        closing: %i[closed unknown cleanup_pending cancelled],
        unknown: %i[active closing cleanup_pending closed cancelled],
        cleanup_pending: %i[closed unknown cancelled],
        closed: [],
        cancelled: []
      }.freeze

      attr_reader :id, :actor_id, :run_id, :state, :budget, :session_id,
                  :idempotency_key, :steps, :bytes, :fence, :error_code,
                  :created_at, :updated_at

      def self.generate_id(prefix: "op")
        "#{prefix}_#{SecureRandom.uuid}"
      end

      def initialize(id:, actor_id:, run_id:, budget:, state: :reserved, session_id: nil,
                     idempotency_key: nil, steps: 0, bytes: 0, fence: 0, error_code: nil,
                     created_at: nil, updated_at: nil)
        @id = string!(id, :id)
        @actor_id = string!(actor_id, :actor_id)
        @run_id = string!(run_id, :run_id)
        @budget = budget!(
          budget
        )
        @state = state!(state)
        @session_id = session_id
        @idempotency_key = idempotency_key
        @steps = count!(steps, :steps)
        @bytes = count!(bytes, :bytes)
        @fence = count!(fence, :fence)
        @error_code = error_code
        @created_at = created_at
        @updated_at = updated_at || created_at
        freeze
      end

      def open? = OPEN_STATES.include?(state)
      def terminal? = TERMINAL_STATES.include?(state)
      def unknown? = state == :unknown
      def cleanup_pending? = state == :cleanup_pending

      def elapsed_seconds(now)
        return 0.0 if created_at.nil?

        (now - created_at).to_f
      end

      # True when the operation has outlived its wall-clock budget.
      def expired?(now)
        elapsed_seconds(now) >= budget.max_seconds
      end

      def remaining_steps = [ budget.max_steps - steps, 0 ].max
      def remaining_bytes = [ budget.max_bytes - bytes, 0 ].max
      def bytes_exhausted? = bytes >= budget.max_bytes
      def steps_exhausted? = steps >= budget.max_steps

      # Advances to +target+, refusing illegal transitions.
      #
      # @param now [Time] timestamp for +updated_at+
      # @param session_id [String, nil] set or clear the provider session id
      # @param error_code [String, nil] record a typed failure code
      def advance(target, now:, session_id: :keep, error_code: :keep)
        target = state!(target)
        validate_transition!(target)
        self.class.new(
          id: id, actor_id: actor_id, run_id: run_id, budget: budget,
          state: target,
          session_id: session_id == :keep ? @session_id : session_id,
          idempotency_key: idempotency_key,
          steps: steps, bytes: bytes, fence: fence,
          error_code: error_code == :keep ? @error_code : error_code,
          created_at: created_at, updated_at: now
        )
      end

      # Records one provider round-trip, refusing to exceed the step budget.
      def consume_step!(now:)
        raise BudgetExhausted, "operation step budget exhausted" if steps_exhausted?

        self.class.new(**to_h.merge(steps: steps + 1, updated_at: now))
      end

      # Records bytes returned by the provider. Bounding/truncation is decided by the
      # caller from {#remaining_bytes}; this never silently drops data.
      def add_bytes!(amount, now:)
        raise InvalidInput, "bytes must be a non-negative integer" unless amount.is_a?(Integer) && amount >= 0

        self.class.new(**to_h.merge(bytes: bytes + amount, updated_at: now))
      end

      # Returns a copy carrying a new fence token.
      def with_fence(value, now: nil)
        raise InvalidInput, "fence must be a non-negative Integer" unless value.is_a?(Integer) && value >= 0

        self.class.new(**to_h.merge(fence: value, updated_at: now || updated_at))
      end

      # True when every field matches except possibly timestamps/fence.
      def same_identity?(other)
        other.is_a?(Operation) && id == other.id && actor_id == other.actor_id && run_id == other.run_id
      end

      def to_h
        {
          id: id, actor_id: actor_id, run_id: run_id, state: state, budget: budget,
          session_id: session_id, idempotency_key: idempotency_key, steps: steps,
          bytes: bytes, fence: fence, error_code: error_code,
          created_at: created_at, updated_at: updated_at
        }
      end

      # An audit-safe summary. Omits the provider session id.
      def summary
        to_h.except(:session_id, :budget, :idempotency_key)
      end

      def ==(other)
        other.is_a?(Operation) && to_h == other.to_h
      end
      alias eql? ==

      def hash = to_h.hash

      def inspect
        "#<#{self.class} id=#{id} state=#{state} actor=#{actor_id} steps=#{steps}/#{budget.max_steps}>"
      end

      private

      def validate_transition!(target)
        return if target == state
        return if TRANSITIONS.fetch(state).include?(target)

        raise InvalidInput, "illegal operation transition #{state} -> #{target}"
      end

      def string!(value, name)
        raise InvalidInput, "#{name} must be a non-empty String" unless value.is_a?(String) && !value.empty?

        value
      end

      def budget!(value)
        raise InvalidInput, "budget must be a RubyLLM::Browser::Budget" unless value.is_a?(Budget)

        value
      end

      def state!(value)
        symbol = value.to_sym
        return symbol if STATES.include?(symbol)

        raise InvalidInput, "unknown operation state #{symbol.inspect}"
      end

      def count!(value, name)
        raise InvalidInput, "#{name} must be a non-negative Integer" unless value.is_a?(Integer) && value >= 0

        value
      end
    end
  end
end
