# frozen_string_literal: true

module RubyLLM
  module Browser
    # An experimental {Backend} adapter for the official `stagehand` Ruby SDK.
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
    # This adapter is unsupported for live operations in the first release. Its
    # capabilities always report unverified egress, so callers cannot enable it by
    # passing a host assertion. Provider egress and cleanup need qualification first.
    class StagehandBackend < Backend
      DEFAULT_BASE_URL = "https://api.stagehand.browserbase.com"
      CUSTOM_HEADERS_ENV = "STAGEHAND_CUSTOM_HEADERS"
      PINNED_BINARY_ENV = "STAGEHAND_SEA_BINARY"
      PINNED_VERSION_ENV = "STAGEHAND_SERVER_VERSION"
      ENV_OVERRIDE_KEYS = %w[STAGEHAND_API_URL STAGEHAND_BASE_URL].freeze

      attr_reader :model_name, :server, :base_url

      # @param browserbase_api_key [String] the Browserbase key
      # @param model_api_key [String] the model provider key
      # @param model_name [String] the model the provider uses for AI browser steps
      # @param server [Symbol, String] `:remote` or `:local`
      # @param base_url [String, nil] explicit endpoint; defaults to the official remote
      #   endpoint. Never read from the environment.
      # @param timeout [Numeric] per-request timeout in seconds
      # @param custom_headers_approved [Boolean] whether the host approved the SDK's
      #   always-merged `STAGEHAND_CUSTOM_HEADERS`
      # @param env [Hash] environment to inspect; injectable for tests
      # @param client [Object, nil] an already-built client (tests/advanced hosts)
      def initialize(browserbase_api_key:, model_api_key:, model_name:,
                     server: :remote, base_url: nil, timeout: 60.0,
                     custom_headers_approved: false, env: ENV, client: nil)
        super()
        @browserbase_api_key = presence!(browserbase_api_key, :browserbase_api_key)
        @model_api_key = presence!(model_api_key, :model_api_key)
        @model_name = presence!(model_name, :model_name)
        @server = server_mode!(server)
        @base_url = base_url.nil? ? default_base_url : presence!(base_url, :base_url)
        @timeout = positive_number!(timeout, :timeout)
        @env = env
        @environment_snapshot = relevant_environment(env)
        @process_environment_snapshot = relevant_environment(ENV)
        @custom_headers_present = !env[CUSTOM_HEADERS_ENV].to_s.empty? || !ENV[CUSTOM_HEADERS_ENV].to_s.empty?
        @custom_headers_approved = !!custom_headers_approved
        @local_binary_pinned = local? && pinned_binary?
        @client_mutex = Mutex.new
        @client = client
        @capabilities = Capabilities.new(
          server_mode: local? ? :local : :remote,
          egress_isolation: :unverified,
          local_binary_pinned: @local_binary_pinned,
          custom_headers_present: @custom_headers_present,
          custom_headers_approved: @custom_headers_approved,
          act_supported: false
        )
      end

      # The pinned credential literals, so the redactor scrubs them from any page text
      # or provider payload that reaches a result.
      def secrets = [ @browserbase_api_key, @model_api_key ]

      def capabilities
        return @capabilities if environment_unchanged?

        Capabilities.new(server_mode: local? ? :local : :remote, egress_isolation: :unverified,
                         custom_headers_present: true, custom_headers_approved: false,
                         act_supported: false)
      end

      def local? = server == "local"

      def start(context:, operation:, now:)
        ensure_qualified!
        response = effectful do
          client.sessions.start(model_name: model_name, self_heal: false, verbose: 0,
                                wait_for_captcha_solves: false,
                                browserbase_session_create_params: {
                                  keep_alive: false, timeout: operation.budget.max_seconds.ceil,
                                  browser_settings: { solve_captchas: false, record_session: false, log_session: false }
                                },
                                request_options: effectful_options(operation, now: now))
        end
        session_id = response.data&.session_id.to_s
        unless response.success == true && !session_id.empty?
          partial = Session.new(id: session_id, started_at: now) unless session_id.empty?
          raise SessionUnknown.new("browser provider did not confirm a session identity", session: partial)
        end

        Session.new(id: session_id, url: nil, started_at: now)
      end

      def navigate(session, url:, operation:, now:)
        ensure_qualified!
        response = effectful do
          client.sessions.navigate(session.id, url: url, request_options: effectful_options(operation, now: now))
        end
        raise SessionUnknown, "browser navigation outcome is unconfirmed" unless response.success == true

        destination = final_url(response)
        unless destination.is_a?(String) && !destination.empty?
          raise SessionUnknown, "browser provider did not verify the final destination URL"
        end
        Session.new(id: session.id, url: destination, started_at: session.started_at)
      end

      def observe(session, instruction:, operation:, now:)
        ensure_qualified!
        response = read do
          client.sessions.observe(session.id, instruction: instruction,
                                             request_options: read_options(operation, now: now))
        end
        raise ProviderError, "browser observation was unsuccessful" unless response.success == true
        Array(response.data&.result).map { |action| observed_action(action) }
      end

      def extract(session, schema:, instruction:, operation:, now:)
        ensure_qualified!
        response = read do
          client.sessions.extract(session.id, schema: schema, instruction: instruction,
                                             request_options: read_options(operation, now: now))
        end
        raise ProviderError, "browser extraction was unsuccessful" unless response.success == true
        dump(response.data&.result)
      end

      def act(session, action:, operation:, now:)
        ensure_qualified!
        raise UnsupportedSecurityCapability, "backend Act is disabled" unless capabilities.act_supported?
        response = effectful do
          client.sessions.act(session.id, input: action_input(action),
                                         request_options: effectful_options(operation, now: now))
        end
        raise SessionUnknown, "browser action outcome is unconfirmed" unless response.success == true
        dump(response.data&.result)
      end

      # Stagehand is unsupported for this release. Do not send even a best-effort
      # cleanup request: the response cannot prove terminal closure, and the owner
      # declined all live provider calls. Keep the operation `cleanup_pending`.
      def end_session(_session, operation:, now:)
        false
      end

      # No provider correlation endpoint is exposed by the SDK, so an unresolved
      # operation cannot be proven closed or active here.
      def reconcile(_operation, now:)
        :unknown
      end

      def inspect
        "#<#{self.class} server=#{server}>"
      end

      private

      def client
        return @client if @client

        @client_mutex.synchronize do
          @client ||= build_client
        end
      end

      def build_client
        raise UnsupportedSecurityCapability, "Stagehand environment changed; rebuild the backend" unless environment_unchanged?
        if local? && ENV[PINNED_BINARY_ENV].to_s.empty? && ENV[PINNED_VERSION_ENV].to_s.empty?
          raise UnsupportedSecurityCapability, "local mode requires a process-level server pin"
        end
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
        raise SessionUnknown, "browser provider connection outcome is unconfirmed", cause: nil
      rescue Stagehand::Errors::APIStatusError => e
        raise translate_status(e), cause: nil
      rescue Stagehand::Errors::Error => e
        raise SessionUnknown, "browser provider outcome is unconfirmed: #{e.class.name.split("::").last}", cause: nil
      end

      # Read-only calls never retry; an ambiguous failure is a plain provider error.
      def read
        yield
      rescue Stagehand::Errors::Error => e
        raise ProviderError, "browser provider error: #{e.class.name.split("::").last}", cause: nil
      end

      def translate_status(error)
        status = error.status.to_i
        if status >= 500 || status == 408
          return SessionUnknown.new("browser provider returned #{status}; outcome unconfirmed")
        end

        ProviderError.new("browser provider rejected the request (status #{status})")
      end

      def effectful_options(operation, now:)
        # The SDK has no configured idempotency header. The durable store, not an
        # ignored request option, prevents duplicate starts and actions.
        read_options(operation, now: now)
      end

      def read_options(operation, now:)
        remaining = operation.budget.max_seconds - operation.elapsed_seconds(now)
        raise BudgetExhausted, "operation wall-clock budget exhausted" unless remaining.positive?

        { max_retries: 0, timeout: [ @timeout, remaining ].min }
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

        value.dup.freeze
      end

      def positive_number!(value, name)
        unless value.is_a?(Numeric) && value.finite? && value.positive?
          raise InvalidInput, "#{name} must be a positive finite number"
        end

        value
      end

      def server_mode!(value)
        mode = value.to_s
        return mode if %w[remote local].include?(mode)

        raise InvalidInput, "server must be :remote or :local"
      end

      def relevant_environment(env)
        Immutable.copy([ CUSTOM_HEADERS_ENV, PINNED_BINARY_ENV, PINNED_VERSION_ENV ].to_h { |key| [ key, env[key] ] })
      end

      def environment_unchanged?
        relevant_environment(@env) == @environment_snapshot &&
          relevant_environment(ENV) == @process_environment_snapshot
      end

      def ensure_qualified!
        current = capabilities
        unless current.enforced_egress? && (!current.local_mode? || current.local_binary_pinned?) &&
            (!current.custom_headers_present? || current.custom_headers_approved?)
          raise UnsupportedSecurityCapability,
                "Stagehand backend is unsupported until provider egress and cleanup are qualified"
        end
        if !ENV[CUSTOM_HEADERS_ENV].to_s.empty? && !@custom_headers_approved
          raise UnsupportedSecurityCapability, "Stagehand process custom headers are not approved"
        end
      end
    end
  end
end
