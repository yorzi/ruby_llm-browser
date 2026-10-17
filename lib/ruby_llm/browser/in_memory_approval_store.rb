# frozen_string_literal: true

module RubyLLM
  module Browser
    # Thread-safe, in-process {ApprovalStore}.
    #
    # A fixture for a single process. Production use needs a durable store so an
    # approval survives a worker restart and cannot be replayed by a second process.
    class InMemoryApprovalStore < ApprovalStore
      def initialize
        super()
        @mutex = Mutex.new
        @approvals = {}
      end

      def issue(approval)
        synchronize do
          raise InvalidInput, "approval #{approval.id} already exists" if @approvals.key?(approval.id)

          @approvals[approval.id] = approval
        end
      end

      def fetch(id)
        synchronize { @approvals[id] }
      end

      def consume_once(id, actor_id:, run_id:, url:, action_digest:, now:, page_revision: nil,
                       operation_id: nil, session_id: nil)
        synchronize do
          approval = @approvals[id]
          raise ApprovalRequired, "no approval #{id.inspect} was issued" if approval.nil?
          raise ApprovalStale, "approval #{id} was already consumed" if approval.consumed?
          raise ApprovalStale, "approval #{id} was revoked" if approval.revoked?
          raise ApprovalStale, "approval #{id} has expired" if approval.expired?(now)

          unless approval.binding_matches?(
            actor_id: actor_id, run_id: run_id, url: url, action_digest: action_digest,
            page_revision: page_revision, operation_id: operation_id, session_id: session_id
          )
            raise ApprovalStale, "approval #{id} does not authorize this actor, URL, page or action"
          end

          consumed = approval.consume!(now: now)
          @approvals[id] = consumed
        end
      end

      def revoke(id)
        synchronize do
          approval = @approvals.fetch(id) { raise ApprovalRequired, "no approval #{id.inspect} was issued" }
          @approvals[id] = approval.revoke!
        end
      end

      def all
        synchronize { @approvals.values.dup }
      end

      private

      def synchronize(&block)
        @mutex.synchronize(&block)
      end
    end
  end
end
