# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Durable {RubyLLM::Browser::ApprovalStore} backed by ActiveRecord.
      #
      # {#consume_once} runs inside a row-locked transaction and performs every check —
      # existence, active, actor/run, URL, page revision, operation/session and exact
      # action digest — before it marks the row consumed. Two workers cannot both consume
      # the same grant, and a replayed or cross-actor approval is refused.
      class ActiveRecordApprovalStore < ApprovalStore
        def initialize(record_class: ApprovalRecord)
          super()
          @record_class = record_class
        end

        def issue(approval)
          @record_class.create!(
            id: approval.id, actor_id: approval.actor_id, run_id: approval.run_id,
            url: approval.url, action_digest: approval.action_digest,
            action: @record_class.dump_action(approval.action),
            page_revision: approval.page_revision, operation_id: approval.operation_id,
            session_id: approval.session_id, issued_at: approval.issued_at,
            expires_at: approval.expires_at, consumed_at: approval.consumed_at,
            revoked: approval.revoked?, created_at: approval.issued_at,
            updated_at: approval.issued_at
          )
          approval
        rescue ActiveRecord::RecordNotUnique
          raise InvalidInput, "approval #{approval.id} already exists"
        end

        def fetch(id)
          @record_class.find_by(id: id)&.to_approval
        end

        def consume_once(id, actor_id:, run_id:, url:, action_digest:, now:, page_revision: nil,
                         operation_id: nil, session_id: nil)
          @record_class.transaction do
            record = locked!(id)
            approval = record.to_approval
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
            record.update!(consumed_at: consumed.consumed_at, updated_at: now)
            consumed
          end
        end

        def revoke(id)
          @record_class.transaction do
            record = locked!(id)
            return record.to_approval if record.revoked

            record.update!(revoked: true, updated_at: Time.now.utc)
            record.to_approval
          end
        end

        private

        def locked!(id)
          @record_class.lock.find_by(id: id) ||
            raise(ApprovalRequired, "no approval #{id.inspect} was issued")
        end
      end
    end
  end
end
