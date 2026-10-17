# frozen_string_literal: true

module RubyLLM
  module Browser
    # Base class for every error this Gem raises deliberately.
    #
    # Each subclass carries a stable, machine-readable +code+ from the documented safe
    # set. Messages are constructed by the Gem and never contain credentials, cookies,
    # +cdp_url+ values or raw page dumps.
    class Error < StandardError
      # The stable code for this error class.
      def self.code
        const_defined?(:CODE, false) ? const_get(:CODE) : "ERROR"
      end

      # The stable code for this error instance, e.g. "INVALID_INPUT".
      def code
        self.class.code
      end

      # A model-safe representation. Callers may hand this straight back to a tool
      # result without leaking internals.
      def to_h
        { code: code, message: message }
      end
    end

    # The caller supplied malformed or out-of-range input.
    class InvalidInput < Error
      CODE = "INVALID_INPUT"
    end

    # The destination, actor, schema or action is not permitted by the host policy.
    class NotAuthorized < Error
      CODE = "NOT_AUTHORIZED"
    end

    # The backend cannot enforce a security capability this Gem requires, so no session
    # may start. Returned *before* any remote call.
    class UnsupportedSecurityCapability < Error
      CODE = "UNSUPPORTED_SECURITY_CAPABILITY"
    end

    # A rendered, step, byte, concurrency or cost budget is exhausted.
    class BudgetExhausted < Error
      CODE = "BUDGET_EXHAUSTED"
    end

    # A remote start or action has no confirmed outcome. Never treated as success and
    # never automatically retried into a second session.
    class SessionUnknown < Error
      CODE = "SESSION_UNKNOWN"
    end

    # Cleanup was attempted but is not confirmed. The reservation is held until closure
    # or expiry is proven.
    class CleanupPending < Error
      CODE = "CLEANUP_PENDING"
    end

    # An action requires a host-issued approval that is missing.
    class ApprovalRequired < Error
      CODE = "APPROVAL_REQUIRED"
    end

    # An approval exists but is expired, revoked, cross-actor, replayed or bound to a
    # different page revision or action digest.
    class ApprovalStale < Error
      CODE = "APPROVAL_STALE"
    end

    # The remote provider returned an error, timed out or is otherwise unavailable.
    class ProviderError < Error
      CODE = "PROVIDER_ERROR"
    end
  end
end
