# frozen_string_literal: true

module RubyLLM
  module Browser
    # Trusted, host-supplied execution context.
    #
    # Context is created by the host application — not the model and not page text — and
    # carries identity, the source policy, the backend, stores, budgets and the data-
    # sharing consent decision. Tools never invent any of it.
    class Context
      attr_reader :actor_id, :run_id, :backend, :source_policy, :operation_store,
                  :approval_store, :budget, :consent, :metadata, :logger

      # @param source_policy [Policy] the host's URL/schema/action/egress policy
      # @param backend [Backend] an egress-qualified backend
      # @param operation_store [OperationStore] durable operation bookkeeping
      # @param approval_store [ApprovalStore, nil] required only for Act
      # @param budget [Budget, nil] defaults to the process default budget
      # @param clock [#call, nil] returns the current UTC Time
      # @param logger [Logger, nil]
      # @param consent [Object, nil] host record of the remote-processing consent
      def initialize(actor_id:, run_id:, backend:, source_policy:, operation_store:,
                     approval_store: nil, budget: nil, clock: nil, logger: nil, consent: nil,
                     metadata: {})
        @actor_id = presence!(actor_id, :actor_id)
        @run_id = presence!(run_id, :run_id)
        @backend = backend!(backend)
        @source_policy = policy!(source_policy)
        @operation_store = store!(operation_store)
        @approval_store = approval_store!(approval_store)
        @budget = budget.nil? ? Configuration.new.default_budget : budget!(budget)
        @clock = clock || RubyLLM::Browser.clock
        @logger = logger || RubyLLM::Browser.logger
        @consent = consent
        @metadata = metadata || {}
        freeze
      end

      # The host policy.
      def policy = source_policy

      def capabilities
        backend.capabilities
      end

      # Current UTC time from the context clock.
      def now
        @clock.call
      end

      # Exact secret values the backend wants scrubbed from page text and results.
      def secrets
        backend.respond_to?(:secrets) ? Array(backend.secrets) : []
      end

      # An audit-safe summary. Never includes backend credentials.
      def to_h
        {
          actor_id: actor_id,
          run_id: run_id,
          budget: budget.to_h,
          consent: !consent.nil?,
          capabilities: capabilities.respond_to?(:to_h) ? capabilities.to_h : capabilities
        }
      end

      def inspect
        "#<#{self.class} actor=#{actor_id} run=#{run_id} backend=#{backend.class}>"
      end

      private

      def presence!(value, name)
        raise InvalidInput, "#{name} must be a non-empty String" unless value.is_a?(String) && !value.empty?

        value
      end

      def backend!(value)
        unless value.is_a?(Backend)
          raise InvalidInput, "backend must be a RubyLLM::Browser::Backend"
        end

        value
      end

      def policy!(value)
        raise InvalidInput, "source_policy must be a RubyLLM::Browser::Policy" unless value.is_a?(Policy)

        value
      end

      def store!(value)
        unless value.is_a?(OperationStore)
          raise InvalidInput, "operation_store must be a RubyLLM::Browser::OperationStore"
        end

        value
      end

      def approval_store!(value)
        return nil if value.nil?
        unless value.is_a?(ApprovalStore)
          raise InvalidInput, "approval_store must be a RubyLLM::Browser::ApprovalStore"
        end

        value
      end

      def budget!(value)
        raise InvalidInput, "budget must be a RubyLLM::Browser::Budget" unless value.is_a?(Budget)

        value
      end
    end
  end
end
