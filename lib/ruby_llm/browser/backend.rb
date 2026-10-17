# frozen_string_literal: true

module RubyLLM
  module Browser
    # A live browser session handle.
    #
    # A session exposes only what policy and provenance need: an id, the current
    # (possibly redirected) URL and a start time. It deliberately has no reader for the
    # provider's `cdp_url`: that is a full-control DevTools endpoint and must never
    # reach a tool result, model message or log.
    class Session
      attr_reader :id, :url, :started_at

      def initialize(id:, url: nil, started_at: nil)
        raise InvalidInput, "session id must be a non-empty String" unless id.is_a?(String) && !id.empty?

        @id = id
        @url = url
        @started_at = started_at
        freeze
      end

      # Returns a copy with a new current URL.
      def with_url(url)
        self.class.new(id: id, url: url, started_at: started_at)
      end

      def to_h
        { id: id, url: url, started_at: started_at&.utc&.iso8601 }
      end

      def inspect = "#<#{self.class} id=#{id} url=#{url.inspect}>"
    end

    # The contract every browser backend implements.
    #
    # The Gem maps its own bounded operations onto a backend; it never reimplements a
    # browser engine. Implementations must:
    #
    # - never raise an untyped error; use {ProviderError} (or {SessionUnknown} when an
    #   effectful call's outcome cannot be confirmed)
    # - issue effectful calls without automatic retries
    # - never return `cdp_url`, cookies or credentials
    # - report honest {Capabilities}
    #
    # {FakeBackend} is the offline reference; {StagehandBackend} wraps the official SDK.
    class Backend
      # @return [Capabilities]
      def capabilities
        raise NotImplementedError, "Backend#capabilities must be implemented"
      end

      # Secret literal values (API keys, ...) to scrub from page text and results.
      # @return [Array<String>]
      def secrets = []

      # Opens a session. Returns a {Session} or raises {SessionUnknown} when the
      # outcome is unconfirmed.
      def start(context:, operation:, now:)
        raise NotImplementedError, "Backend#start must be implemented"
      end

      # Navigates +session+ to +url+. Returns the updated {Session}.
      def navigate(_session, url:, operation:, now:)
        raise NotImplementedError, "Backend#navigate must be implemented"
      end

      # @return [Array<Hash>] candidate actions, each with `description`, `method`,
      #   `selector` and optional `arguments`
      def observe(_session, instruction:, operation:, now:)
        raise NotImplementedError, "Backend#observe must be implemented"
      end

      # @return [Hash] structured data matching +schema+
      def extract(_session, schema:, instruction:, operation:, now:)
        raise NotImplementedError, "Backend#extract must be implemented"
      end

      # Dispatches one already-authorized action. Raises {SessionUnknown} when the
      # outcome after dispatch cannot be confirmed.
      def act(_session, action:, operation:, now:)
        raise NotImplementedError, "Backend#act must be implemented"
      end

      # Attempts to terminate +session+. Returns true only when closure is confirmed.
      def end_session(_session, operation:, now:)
        raise NotImplementedError, "Backend#end_session must be implemented"
      end

      # Resolves an operation whose remote outcome is unconfirmed.
      #
      # @return [Symbol] one of :closed, :active, :unknown, :cleanup_pending
      def reconcile(_operation, now:)
        :unknown
      end
    end
  end
end
