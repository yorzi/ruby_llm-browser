# frozen_string_literal: true

module RubyLLM
  module Browser
    # The reference {Backend}, wrapping the official `stagehand` Ruby SDK.
    #
    # It is a thin, fail-closed translation layer, not a browser engine. It:
    #
    # - constructs `Stagehand::Client` with **every** argument explicit, so the SDK's
    #   environment defaults (`STAGEHAND_API_URL`/`STAGEHAND_BASE_URL`,
    #   `BROWSERBASE_API_KEY`, `MODEL_API_KEY`) can never redirect or authenticate a call
    # - requires `max_retries: 0`, both at the client and per effectful request, because
    #   the SDK otherwise retries errors and timeouts
    # - never returns `cdp_url`, cookies or credentials, and reports the pinned API keys
    #   as secret literals so they are scrubbed from page text and results
    # - refuses to construct a live client in local mode unless a host-pinned server
    #   binary or version is present, so it never triggers the SDK's runtime download
    #
    # The SDK is required lazily, inside {#client}, so requiring this Gem never reads
    # Stagehand environment variables and never starts or downloads a server.
    #
    # Egress isolation is a property of the deployment, not of this class. A host must
    # pass `egress_isolation: :enforced` only after it has qualified the actual browser
    # network. Until then, {Policy#authorize_egress!} refuses to start a session.
    class StagehandBackend < Backend
      DEFAULT_BASE_URL = "https://api.stagehand.browserbase.com"
      CUSTOM_HEADERS_ENV = "STAGEHAND_CUSTOM_HEADERS"
      PINNED_BINARY_ENV = "STAGEHAND_SEA_BINARY"
      PINNED_VERSION_ENV = "STAGEHAND_SERVER_VERSION"
      ENV_OVERRIDE_KEYS = %w[STAGEHAND_API_URL STAGEHAND_BASE_URL].freeze

      attr_reader :model_name, :server, :base_url, :capabilities

      # @param browserbase_api_key [String] the Browserbase key
      # @param model_api_key [String] the model provider key
      # @param model_name [String] the model the provider uses for AI browser steps
      # @param server [Symbol, String] `:remote` or `:local`
      # @param base_url [String, nil] explicit endpoint; defaults to the official remote
      #   endpoint. Never read from the environment.
      # @param timeout [Numeric] per-request timeout in seconds
      # @param egress_isolation [Symbol] host's assertion; `:enforced` only after
      #   qualifying the browser network, otherwise `:unverified`
      # @param act_supported [Boolean]
      # @param custom_headers_approved [Boolean] whether the host approved the SDK's
      #   always-merged `STAGEHAND_CUSTOM_HEADERS`
      # @param env [Hash] environment to inspect; injectable for tests
      # @param client [Object, nil] an already-built client (tests/advanced hosts)
      def initialize(browserbase_api_key:, model_api_key:, model_name:,
                     server: :remote, base_url: nil, timeout: 60.0,
                     egress_isolation: :unverified, act_supported: true,
                     custom_headers_approved: false, env: ENV, client: nil)
        super()
        @browserbase_api_key = presence!(browserbase_api_key, :browserbase_api_key)
        @model_api_key = presence!(model_api_key, :model_api_key)
        @model_name = presence!(model_name, :model_name)
        @server = server_mode!(server)
        @base_url = base_url.nil? ? default_base_url : presence!(base_url, :base_url)
        @timeout = positive_number!(timeout, :timeout)
        @env = env
        @custom_headers_present = !env[CUSTOM_HEADERS_ENV].to_s.empty?
        @custom_headers_approved = !!custom_headers_approved
        @local_binary_pinned = local? && pinned_binary?
        @client_mutex = Mutex.new
        @client = client
        @capabilities = Capabilities.new(
          server_mode: local? ? :local : :remote,
          egress_isolation: egress_isolation,
          local_binary_pinned: @local_binary_pinned,
          custom_headers_present: @custom_headers_present,
          custom_headers_approved: @custom_headers_approved,
          act_supported: act_supported
        )
      end

      # The pinned credential literals, so the redactor scrubs them from any page text
      # or provider payload that reaches a result.
      def secrets = [ @browserbase_api_key, @model_api_key ]

      def local? = server == "local"

      def start(context:, operation:, now:)
        response = effectful do
          client.sessions.start(model_name: model_name, request_options: effectful_options(operation))
        end
        session_id = response.data&.session_id.to_s
        raise ProviderError, "browser provider did not return a session id" if session_id.empty?

        Session.new(id: session_id, url: nil, started_at: now)
      end

      def navigate(session, url:, operation:, now:)
        response = effectful do
          client.sessions.navigate(session.id, url: url, request_options: effectful_options(operation))
        end
        Session.new(id: session.id, url: final_url(response) || url, started_at: session.started_at)
      end

      def observe(session, instruction:, operation:, now:)
        response = read do
          client.sessions.observe(session.id, instruction: instruction,
                                             request_options: read_options(operation))
        end
        Array(response.data&.result).map { |action| observed_action(action) }
      end

      def extract(session, schema:, instruction:, operation:, now:)
        response = read do
          client.sessions.extract(session.id, schema: schema, instruction: instruction,
                                             request_options: read_options(operation))
        end
        dump(response.data&.result)
      end

      def act(session, action:, operation:, now:)
        response = effectful do
          client.sessions.act(session.id, input: action_input(action),
                                         request_options: effectful_options(operation))
        end
        dump(response.data&.result)
      end

      # Returns true only when the provider confirms closure. Any unconfirmed or failed
      # outcome returns false so the operation stays `cleanup_pending`.
      def end_session(session, operation:, now:)
        response = client.sessions.end_(session.id, request_options: effectful_options(operation))
        response.success == true
      rescue Stagehand::Errors::Error
        false
      end

      # No provider correlation endpoint is exposed by the SDK, so an unresolved
      # operation cannot be proven closed or active here.
      def reconcile(_operation, now:)
        :unknown
      end

      def inspect
        "#<#{self.class} server=#{server} base_url=#{base_url} model=#{model_name}>"
      end

      private

      def client
        return @client if @client

        @client_mutex.synchronize do
          @client ||= build_client
        end
      end

      def build_client
        require "stagehand"
        Stagehand::Client.new(
          browserbase_api_key: @browserbase_api_key,
          model_api_key: @model_api_key,
          server: @server,
          base_url: @base_url,
          max_retries: 0,
          timeout: @timeout
        )
      end

      # Effectful calls never retry and, when the outcome is ambiguous, never claim
      # success: a connection error or a 5xx becomes {SessionUnknown}.
      def effectful
        yield
      rescue Stagehand::Errors::APIConnectionError
        raise SessionUnknown, "browser provider connection outcome is unconfirmed"
      rescue Stagehand::Errors::APIStatusError => e
        raise translate_status(e)
      rescue Stagehand::Errors::Error => e
        raise ProviderError, "browser provider error: #{e.class.name.split("::").last}"
      end

      # Read-only calls never retry; an ambiguous failure is a plain provider error.
      def read
        yield
      rescue Stagehand::Errors::Error => e
        raise ProviderError, "browser provider error: #{e.class.name.split("::").last}"
      end

      def translate_status(error)
        status = error.status.to_i
        return SessionUnknown.new("browser provider returned #{status}; outcome unconfirmed") if status >= 500

        ProviderError.new("browser provider rejected the request (status #{status})")
      end

      def effectful_options(operation)
        { max_retries: 0, idempotency_key: operation.id }
      end

      def read_options(_operation)
        { max_retries: 0 }
      end

      def action_input(action)
        {
          "description" => action["description"],
          "selector" => action["selector"],
          "method" => action["method"],
          "arguments" => Array(action["arguments"])
        }
      end

      def observed_action(action)
        {
          "description" => attribute(action, :description),
          "method" => attribute(action, :method_) || attribute(action, :method),
          "selector" => attribute(action, :selector),
          "arguments" => Array(attribute(action, :arguments))
        }
      end

      def attribute(action, name)
        if action.respond_to?(name)
          action.public_send(name)
        elsif action.is_a?(Hash)
          action[name.to_s] || action[name]
        end
      end

      # Converts SDK model objects into plain, string-keyed JSON-safe data.
      def dump(value)
        case value
        when Hash
          value.to_h { |key, nested| [ key.to_s, dump(nested) ] }
        when Array
          value.map { |item| dump(item) }
        else
          value.respond_to?(:to_h) && !value.is_a?(String) ? dump(value.to_h) : value
        end
      end

      def final_url(response)
        result = response.data&.result
        return nil unless result.is_a?(Hash)

        result["url"] || result[:url]
      end

      def pinned_binary?
        !@env[PINNED_BINARY_ENV].to_s.empty? || !@env[PINNED_VERSION_ENV].to_s.empty?
      end

      def default_base_url
        local? ? "http://127.0.0.1" : DEFAULT_BASE_URL
      end

      def presence!(value, name)
        raise InvalidInput, "#{name} must be a non-empty String" unless value.is_a?(String) && !value.empty?

        value
      end

      def positive_number!(value, name)
        raise InvalidInput, "#{name} must be a positive number" unless value.is_a?(Numeric) && value.positive?

        value
      end

      def server_mode!(value)
        mode = value.to_s
        return mode if %w[remote local].include?(mode)

        raise InvalidInput, "server must be :remote or :local"
      end
    end
  end
end
