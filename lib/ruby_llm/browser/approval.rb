# frozen_string_literal: true

module RubyLLM
  module Browser
    # A host-issued, single-use authorization for one exact browser action.
    #
    # An approval binds actor, run, optional operation/session, the exact normalized URL,
    # an optional page revision and the exact action digest, with a short expiry. It is
    # consumed atomically once, immediately before dispatch, inside the tool. A bare
    # RubyLLM `Chat#approve` carries none of these bindings and therefore dispatches
    # nothing on its own.
    class Approval
      attr_reader :id, :actor_id, :run_id, :url, :action_digest, :page_revision,
                  :operation_id, :session_id, :issued_at, :expires_at, :consumed_at

      def initialize(id:, actor_id:, run_id:, url:, action_digest:, expires_at:, issued_at:,
                     page_revision: nil, operation_id: nil, session_id: nil, consumed_at: nil,
                     revoked: false)
        @id = presence!(id, :id)
        @actor_id = presence!(actor_id, :actor_id)
        @run_id = presence!(run_id, :run_id)
        @url = presence!(url, :url)
        @action_digest = presence!(action_digest, :action_digest)
        @expires_at = time!(expires_at, :expires_at)
        @issued_at = time!(issued_at, :issued_at)
        @page_revision = page_revision
        @operation_id = operation_id
        @session_id = session_id
        @consumed_at = consumed_at
        @revoked = !!revoked
        freeze
      end

      # Builds an approval for +action+ with a time-to-live.
      #
      # @param action [Hash] an action already normalized by {Policy#authorize_action!}
      # @param ttl [Numeric] seconds until expiry
      def self.for_action(actor_id:, run_id:, url:, action:, ttl:, now:, id: nil, page_revision: nil,
                          operation_id: nil, session_id: nil)
        new(
          id: id || Operation.generate_id(prefix: "apr"),
          actor_id: actor_id, run_id: run_id, url: url,
          action_digest: action_digest(action),
          page_revision: page_revision, operation_id: operation_id, session_id: session_id,
          issued_at: now, expires_at: now + ttl
        )
      end

      # The digest a host and the Gem both compute for an action.
      def self.action_digest(action)
        Redactor.digest(action)
      end

      # The digest a host and the Gem both compute for an observed candidate list.
      def self.page_revision(observed)
        Redactor.digest(observed)
      end

      def consumed? = !@consumed_at.nil?
      def revoked? = !!@revoked
      def expired?(now) = now >= expires_at
      def active?(now) = !consumed? && !revoked? && !expired?(now)

      # True when the approval authorizes exactly this actor/run/url/revision/digest.
      def binding_matches?(actor_id:, run_id:, url:, action_digest:, page_revision: nil,
                           operation_id: nil, session_id: nil)
        return false unless @actor_id == actor_id && @run_id == run_id
        return false unless @url == url
        return false unless @action_digest == action_digest
        return false unless @page_revision.nil? || @page_revision == page_revision
        return false unless @operation_id.nil? || @operation_id == operation_id
        return false unless @session_id.nil? || @session_id == session_id

        true
      end

      # Returns a consumed copy.
      def consume!(now:)
        raise ApprovalStale, "approval #{id} was already consumed" if consumed?

        copy(consumed_at: now)
      end

      # Returns a revoked copy.
      def revoke!
        copy(revoked: true)
      end
      def to_h
        {
          id: id, actor_id: actor_id, run_id: run_id, url: url,
          action_digest: action_digest, page_revision: page_revision,
          operation_id: operation_id, issued_at: issued_at, expires_at: expires_at,
          consumed_at: consumed_at
        }
      end

      def digest = Redactor.digest(to_h)

      def inspect
        "#<#{self.class} id=#{id} actor=#{actor_id} url=#{url.inspect} expires_at=#{expires_at&.utc&.iso8601}>"
      end

      private

      def copy(consumed_at: @consumed_at, revoked: @revoked)
        self.class.new(
          id: id, actor_id: actor_id, run_id: run_id, url: url, action_digest: action_digest,
          page_revision: page_revision, operation_id: operation_id, session_id: session_id,
          issued_at: issued_at, expires_at: expires_at, consumed_at: consumed_at, revoked: revoked
        )
      end

      def presence!(value, name)
        raise InvalidInput, "#{name} must be a non-empty String" unless value.is_a?(String) && !value.empty?

        value
      end

      def time!(value, name)
        raise InvalidInput, "#{name} must be a Time" unless value.is_a?(Time)

        value
      end
    end
  end
end
