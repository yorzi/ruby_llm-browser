# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Durable row for one browser operation.
      #
      # The record is a projection of {RubyLLM::Browser::Operation}: the store is the
      # only writer, and every write goes through a transaction that checks the fence
      # token, so a stale, duplicated or cancelled worker cannot overwrite newer state.
      class OperationRecord < ActiveRecord::Base
        self.table_name = "ruby_llm_browser_operations"

        # The domain object owns its own timestamps (driven by the injected clock), so
        # ActiveRecord must not overwrite them on save.
        self.record_timestamps = false

        # Rebuilds the immutable domain object from persisted columns.
        def to_operation
          Operation.new(
            id: id, actor_id: actor_id, run_id: run_id, state: state.to_sym,
            session_id: session_id, idempotency_key: idempotency_key,
            steps: steps, bytes: bytes, fence: fence, error_code: error_code,
            budget: self.class.load_budget(budget),
            created_at: self.class.to_time(created_at), updated_at: self.class.to_time(updated_at)
          )
        end

        def self.load_budget(value)
          case value
          when Budget then value
          when String then Budget.new(**JSON.parse(value, symbolize_names: true))
          when Hash then Budget.new(**value.to_h { |key, nested| [ key.to_sym, nested ] })
          else raise InvalidInput, "stored operation budget is missing or malformed"
          end
        end

        def self.dump_budget(budget)
          Redactor.canonical_json(budget.to_h)
        end

        # ActiveRecord hands back +ActiveSupport::TimeWithZone+, which is not a +Time+.
        # The domain objects insist on real +Time+ values.
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
