# frozen_string_literal: true

# RubyLLM::Browser is an unofficial community extension for RubyLLM that adds
# policy-bound browser tools backed by the official Stagehand Ruby SDK.
#
#   require "ruby_llm"
#   require "ruby_llm/browser"
#
# Requiring this file loads the RubyLLM Tool protocol and this Gem only. It does not
# load Rails, read Stagehand environment variables, discover credentials or open a
# browser session.
require "ruby_llm"

require_relative "browser/version"
require_relative "browser/errors"
require_relative "browser/immutable"
require_relative "browser/redactor"
require_relative "browser/budget"
require_relative "browser/result"
require_relative "browser/configuration"
require_relative "browser/capabilities"
require_relative "browser/url_guard"
require_relative "browser/policy"
require_relative "browser/operation"
require_relative "browser/operation_store"
require_relative "browser/in_memory_operation_store"
require_relative "browser/approval"
require_relative "browser/approval_store"
require_relative "browser/in_memory_approval_store"
require_relative "browser/backend"
require_relative "browser/fake_backend"
require_relative "browser/stagehand_backend"
require_relative "browser/doctor"
require_relative "browser/context"
require_relative "browser/engine"
require_relative "browser/tool"
require_relative "browser/tools/inspect"
require_relative "browser/tools/extract"
require_relative "browser/tools/act"

module RubyLLM
  # Policy-bound browser tools for RubyLLM agents.
  #
  # The host application owns identity, authorization, consent and the qualified
  # backend; this namespace owns URL/source policy, bounded results and provenance,
  # operation and session lifecycle, budgets and one-use action approvals.
  module Browser
    class << self
      # Process-wide defaults (see {Configuration}).
      def configuration
        @configuration ||= Configuration.new
      end

      # Yields the shared configuration.
      #
      #   RubyLLM::Browser.configure do |config|
      #     config.max_result_bytes = 32_768
      #   end
      def configure
        yield configuration if block_given?
        configuration
      end

      # Restores the process-wide defaults. Primarily a test helper.
      def reset_configuration!
        @configuration = Configuration.new
      end

      def logger
        configuration.logger
      end

      def clock
        configuration.clock
      end
    end
  end
end
