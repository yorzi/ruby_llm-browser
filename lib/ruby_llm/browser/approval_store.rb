# frozen_string_literal: true

module RubyLLM
  module Browser
    # Durable store for host-issued, single-use {Approval}s.
    #
    # The RubyLLM approval resolver may consult the store repeatedly, so reads must be
    # side-effect free. Only {#consume_once} mutates, and it must be atomic so a replayed
    # or duplicated worker cannot dispatch a second action.
    class ApprovalStore
      # Stores a freshly issued approval.
      def issue(_approval)
        raise NotImplementedError, "ApprovalStore#issue must be implemented"
      end

      # Read-only lookup. Returns an {Approval} or nil.
      def fetch(_id)
        raise NotImplementedError, "ApprovalStore#fetch must be implemented"
      end

      # Atomically consumes +id+ exactly once if it is active and bound to this
      # actor/run/url/revision/digest.
      #
      # @return [Approval] the consumed approval
      # @raise [ApprovalRequired] no such approval
      # @raise [ApprovalStale] consumed, revoked, expired or bound to different details
      def consume_once(_id, actor_id:, run_id:, url:, action_digest:, now:, page_revision: nil,
                       operation_id: nil, session_id: nil)
        raise NotImplementedError, "ApprovalStore#consume_once must be implemented"
      end

      # Revokes an approval so it can never be consumed.
      def revoke(_id)
        raise NotImplementedError, "ApprovalStore#revoke must be implemented"
      end
    end
  end
end
