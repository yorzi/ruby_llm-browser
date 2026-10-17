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
require_relative "browser/redactor"
require_relative "browser/budget"
require_relative "browser/result"
require_relative "browser/configuration"

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
