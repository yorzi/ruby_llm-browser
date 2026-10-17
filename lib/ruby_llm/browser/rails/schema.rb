# frozen_string_literal: true

module RubyLLM
  module Browser
    module Rails
      # Canonical table definitions for the durable Rails adapter.
      #
      # This is a plain-Ruby equivalent of the install generator's migration, so tests
      # and non-migrated fixtures can create the schema directly:
      #
      #   RubyLLM::Browser::Rails::Schema.create!(ActiveRecord::Base.connection)
      module Schema
        OPERATIONS_TABLE = "ruby_llm_browser_operations"
        APPROVALS_TABLE = "ruby_llm_browser_approvals"

        module_function

        # Creates any missing tables. Existing tables are left untouched, so this is
        # safe to call from a test harness or a boot task.
        def create!(connection = ActiveRecord::Base.connection)
          create_operations!(connection) unless connection.table_exists?(OPERATIONS_TABLE)
          create_approvals!(connection) unless connection.table_exists?(APPROVALS_TABLE)
          true
        end

        def create_operations!(connection)
          connection.create_table(OPERATIONS_TABLE, id: false) do |table|
            table.string :id, null: false, primary_key: true
            table.string :actor_id, null: false
            table.string :run_id, null: false
            table.string :state, null: false
            table.string :session_id
            table.string :idempotency_key
            table.integer :steps, null: false, default: 0
            table.integer :bytes, null: false, default: 0
            table.integer :fence, null: false, default: 0
            table.string :error_code
            table.text :budget, null: false
            table.datetime :created_at
            table.datetime :updated_at

            table.index [ :actor_id, :run_id, :idempotency_key ], unique: true,
                                                                 name: "index_ruby_llm_browser_operations_on_idempotency",
                                                                 where: "idempotency_key IS NOT NULL"
            table.index %i[actor_id state], name: "index_ruby_llm_browser_operations_on_actor_state"
            table.index :state, name: "index_ruby_llm_browser_operations_on_state"
          end
        end

        def create_approvals!(connection)
          connection.create_table(APPROVALS_TABLE, id: false) do |table|
            table.string :id, null: false, primary_key: true
            table.string :actor_id, null: false
            table.string :run_id, null: false
            table.string :url, null: false
            table.string :action_digest, null: false
            table.text :action
            table.string :page_revision
            table.string :operation_id
            table.string :session_id
            table.datetime :issued_at, null: false
            table.datetime :expires_at, null: false
            table.datetime :consumed_at
            table.boolean :revoked, null: false, default: false
            table.datetime :created_at
            table.datetime :updated_at

            table.index %i[actor_id run_id], name: "index_ruby_llm_browser_approvals_on_actor_run"
          end
        end
      end
    end
  end
end
