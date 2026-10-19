# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "tmpdir"
require "fileutils"

RSpec.describe "Rails install generator" do
  it "preserves 0.2 rows, indexes and migration history during a no-migration upgrade" do
    generator = Rails::Generators.find_by_namespace("ruby_llm:browser:install")
    Dir.mktmpdir("browser-generator-upgrade") do |directory|
      migration_dir = File.join(directory, "db/migrate")
      FileUtils.mkdir_p(migration_dir)
      baseline = File.read(File.expand_path("../fixtures/v0_2_tables.rb", __dir__))
      path = File.join(migration_dir, "20261018000000_create_ruby_llm_browser_tables.rb")
      File.write(path, baseline)
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(directory, "upgrade.sqlite3"))
      stub_const("CreateRubyLlmBrowserTables", Class.new(ActiveRecord::Migration[8.0]))
      load path
      migration = Object.const_get(:CreateRubyLlmBrowserTables).new
      migration.suppress_messages { migration.migrate(:up) }
      operation = build_operation(id: "old-closed", state: :closed, session_id: "old-session", idempotency_key: "old-key")
      rails_store.reserve(operation)
      RubyLLM::Browser::Rails::ApprovalRecord.create!(
        id: "old-approval", actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/",
        action_digest: "old-digest", issued_at: fixed_time, expires_at: fixed_time + 300,
        consumed_at: fixed_time, revoked: true
      )
      models = [ RubyLLM::Browser::Rails::OperationRecord, RubyLLM::Browser::Rails::ApprovalRecord,
                 RubyLLM::Browser::Rails::ActorRecord ]
      before = models.map { |model| model.order(:id).map(&:attributes) }
      connection = ActiveRecord::Base.connection
      indexes = connection.indexes("ruby_llm_browser_operations").map { |index| [ index.name, index.columns, index.unique, index.where ] }

      # 0.3 adds no gem migration. Fixture schema boot is idempotent; a skipped
      # duplicate generation must preserve the existing migration and all rows.
      RubyLLM::Browser::Rails::Schema.create!
      generator.start([], destination_root: directory, quiet: true, skip: true)

      expect(File.read(path)).to eq(baseline)
      expect(Dir[File.join(migration_dir, "*.rb")]).to eq([ path ])
      expect(models.map { |model| model.order(:id).map(&:attributes) }).to eq(before)
      expect(connection.indexes("ruby_llm_browser_operations").map { |index| [ index.name, index.columns, index.unique, index.where ] }).to eq(indexes)
      expect(rails_store.fetch(operation.id).state).to eq(:closed)
    end
  ensure
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    RubyLLM::Browser::Rails::Schema.create!
    RubyLLM::Browser::Rails::OperationRecord.reset_column_information
    RubyLLM::Browser::Rails::ApprovalRecord.reset_column_information
    RubyLLM::Browser::Rails::ActorRecord.reset_column_information
  end

  it "resolves the documented command and runs its reversible migration" do
    generator = Rails::Generators.find_by_namespace("ruby_llm:browser:install")
    expect(generator).not_to be_nil

    Dir.mktmpdir("browser-generator") do |directory|
      generator.start([], destination_root: directory, quiet: true)
      path = Dir[File.join(directory, "db/migrate/*create_ruby_llm_browser_tables.rb")].fetch(0)
      # Isolated database: the generated migration must work, not just look correct.
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(directory, "migration.sqlite3"))
      stub_const("CreateRubyLlmBrowserTables", Class.new(ActiveRecord::Migration[ActiveRecord::Migration.current_version]))
      load path
      migration = Object.const_get(:CreateRubyLlmBrowserTables).new
      migration.suppress_messages { migration.migrate(:up) }
      expect(ActiveRecord::Base.connection.tables).to include("ruby_llm_browser_operations", "ruby_llm_browser_approvals",
                                                            "ruby_llm_browser_actors")
      migration.suppress_messages { migration.migrate(:down) }
      expect(ActiveRecord::Base.connection.tables).not_to include("ruby_llm_browser_operations")
    end
  ensure
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    RubyLLM::Browser::Rails::Schema.create!
    RubyLLM::Browser::Rails::OperationRecord.reset_column_information
    RubyLLM::Browser::Rails::ApprovalRecord.reset_column_information
    RubyLLM::Browser::Rails::ActorRecord.reset_column_information
  end
end
