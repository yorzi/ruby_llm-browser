# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Durable row for a host-issued single-use {RubyLLM::Browser::Approval}.
      #
      # Only {ActiveRecordApprovalStore#consume_once} mutates a consumed approval, and it
      # does so inside a row-locked transaction so two workers cannot both consume the
      # same grant.
      class ApprovalRecord < ActiveRecord::Base
        self.table_name = "ruby_llm_browser_approvals"

        # Approval timestamps come from the host clock, not from ActiveRecord.
        self.record_timestamps = false

        def to_approval
          Approval.new(
            id: id, actor_id: actor_id, run_id: run_id, url: url,
            action_digest: action_digest, action: self.class.load_action(action),
            page_revision: page_revision, operation_id: operation_id, session_id: session_id,
            issued_at: self.class.to_time(issued_at), expires_at: self.class.to_time(expires_at),
            consumed_at: self.class.to_time(consumed_at), revoked: revoked
          )
        end

        def self.load_action(value)
          return nil if value.nil?

          value.is_a?(String) ? JSON.parse(value) : value
        end

        def self.dump_action(action)
          return nil if action.nil?

          Redactor.canonical_json(action)
        end

        def self.to_time(value)
          case value
          when nil then nil
          when Time then value
          else value.respond_to?(:to_time) ? value.to_time : value
          end
        end
      end
    end
  end
end
