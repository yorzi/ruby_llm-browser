# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "tmpdir"

RSpec.describe "Rails install generator" do
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
