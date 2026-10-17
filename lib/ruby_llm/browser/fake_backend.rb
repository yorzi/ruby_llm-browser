# frozen_string_literal: true

module RubyLLM
  module Browser
    # Offline reference backend.
    #
    # It performs no network I/O at all, so it can honestly claim enforced egress
    # isolation, and it never opens a paid session. Tests script its responses and
    # inspect the recorded calls; it is the required default in CI.
    #
    # It does **not** prove anything about a real provider's network isolation, TTL or
    # billing.
    class FakeBackend < Backend
      DEFAULT_OBSERVE = [
        { "description" => "Open the documentation link", "method" => "click",
          "selector" => "a#docs", "arguments" => [] }
      ].freeze

      DEFAULT_EXTRACT = { "title" => "Example" }.freeze
      DEFAULT_ACT = { "success" => true, "message" => "clicked", "actions" => [] }.freeze

      attr_reader :calls

      # @param capabilities [Capabilities] defaults to an egress-qualified fake backend
      # @param start_error [Exception, nil] raised by {#start}
      # @param navigate_error [Exception, nil]
      # @param observe_error [Exception, nil]
      # @param extract_error [Exception, nil]
      # @param act_error [Exception, nil]
      # @param end_error [Exception, nil]
      # @param redirect_to [String, nil] simulate an in-provider redirect on navigate
      # @param end_confirmed [Boolean] whether {#end_session} confirms closure
      # @param reconcile_state [Symbol] what {#reconcile} reports
      # @param session_id [String] the id returned by {#start}
      def initialize(capabilities: nil, observe: nil, extract: nil, act: nil,
                     start_error: nil, navigate_error: nil, observe_error: nil,
                     extract_error: nil, act_error: nil, end_error: nil,
                     redirect_to: nil, end_confirmed: true, reconcile_state: :closed,
                     session_id: "fake-session-1")
        super()
        @capabilities = capabilities || Capabilities.new(
          server_mode: :fake, egress_isolation: :enforced, act_supported: true
        )
        @observe = observe || DEFAULT_OBSERVE
        @extract = extract || DEFAULT_EXTRACT
        @act = act || DEFAULT_ACT
        @start_error = start_error
        @navigate_error = navigate_error
        @observe_error = observe_error
        @extract_error = extract_error
        @act_error = act_error
        @end_error = end_error
        @redirect_to = redirect_to
        @end_confirmed = end_confirmed
        @reconcile_state = reconcile_state
        @session_id = session_id
        @calls = []
        @started = 0
      end

      attr_reader :capabilities

      def start(context:, operation:, now:)
        record(:start, actor_id: context.actor_id, run_id: context.run_id, operation_id: operation.id)
        raise @start_error if @start_error

        @started += 1
        Session.new(id: @started > 1 ? "#{@session_id}-#{@started}" : @session_id, started_at: now)
      end

      def navigate(session, url:, operation:, now:)
        record(:navigate, url: url, operation_id: operation.id)
        raise @navigate_error if @navigate_error

        session.with_url(@redirect_to || url)
      end

      def observe(_session, instruction:, operation:, now:)
        record(:observe, instruction: instruction, operation_id: operation.id)
        raise @observe_error if @observe_error

        deep_dup(@observe)
      end

      def extract(_session, schema:, instruction:, operation:, now:)
        record(:extract, schema: schema, instruction: instruction, operation_id: operation.id)
        raise @extract_error if @extract_error

        deep_dup(@extract)
      end

      def act(_session, action:, operation:, now:)
        record(:act, action: action, operation_id: operation.id)
        raise @act_error if @act_error

        deep_dup(@act)
      end

      def end_session(_session, operation:, now:)
        record(:end_session, operation_id: operation.id)
        raise @end_error if @end_error

        @end_confirmed
      end

      def reconcile(_operation, now:)
        @reconcile_state
      end

      def called?(method_name)
        @calls.any? { |call| call[:method] == method_name.to_sym }
      end

      def call_count(method_name)
        @calls.count { |call| call[:method] == method_name.to_sym }
      end

      private

      def record(method_name, **payload)
        @calls << { method: method_name, **payload }
      end

      def deep_dup(value)
        case value
        when Hash then value.to_h { |key, nested| [ key, deep_dup(nested) ] }
        when Array then value.map { |item| deep_dup(item) }
        when String then value.dup
        else value
        end
      end
    end
  end
end
