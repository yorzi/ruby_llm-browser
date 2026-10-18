# frozen_string_literal: true

module RubyLLM
  module Browser
    # Base class for the Gem's RubyLLM tools.
    #
    # A tool is a thin, policy-free adapter. The host injects exactly one trusted
    # {Context}; the tool forwards model-supplied arguments to an {Engine}, and the
    # engine enforces egress qualification, destination/schema/action policy, budgets,
    # operation lifecycle and result redaction. A tool never invents an actor, a
    # backend, a schema or an approval, and it never turns a typed failure into an
    # untyped exception that would abort the chat.
    #
    # Model-facing names are declared explicitly so they stay stable across releases.
    class Tool < RubyLLM::Tool
      class << self
        # Declares or returns the stable, model-facing tool name.
        #
        #   tool_name "browser_inspect"
        def tool_name(value = nil)
          return @tool_name if value.nil?

          @tool_name = value
        end
      end

      attr_reader :context

      # @param context [Context] the host-supplied, trusted execution context
      def initialize(context:)
        super()
        @context = context!(context)
        @engine = Engine.new(context: @context)
      end

      private

      # Reports coarse progress when the host's RubyLLM exposes the 2.1+ API.
      #
      # The Gem's floor stays at RubyLLM 2.0, where {RubyLLM::Tool#progress} does not
      # exist, so the call is feature-detected rather than assumed.
      def report(message = nil, value: nil, total: nil)
        return unless respond_to?(:progress)

        progress(message, value: value, total: total)
      end

      # Converts a typed engine error into a model-safe tool result. The stable error
      # code is preserved; the message is Gem-authored and never contains secrets.
      def failure(error)
        message = Redactor.scrub_string(error.message, secrets: context.secrets)
        Result.failure(:error, error_code: error.code, message: message).to_h
      end

      def unexpected_failure
        failure(ProviderError.new("browser operation could not be completed"))
      end

      def engine = @engine

      def context!(value)
        unless value.is_a?(Context)
          raise InvalidInput, "context must be a RubyLLM::Browser::Context"
        end

        value
      end
    end
  end
end
