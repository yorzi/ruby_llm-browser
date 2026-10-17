# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RubyLLM
  module Browser
    module Generators
      # Generates the durable tables for the optional Rails adapter.
      #
      #   bin/rails generate ruby_llm:browser:install
      class InstallGenerator < ::Rails::Generators::Base
        include ::ActiveRecord::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        desc "Creates the RubyLLM::Browser operations and approvals migration"

        def create_migration_file
          migration_template(
            "create_ruby_llm_browser_tables.rb.tt",
            "db/migrate/create_ruby_llm_browser_tables.rb"
          )
        end
      end
    end
  end
end
