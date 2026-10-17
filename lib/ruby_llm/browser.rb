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

module RubyLLM
  # Policy-bound browser tools for RubyLLM agents.
  #
  # The host application owns identity, authorization, consent and the qualified
  # backend; this namespace owns URL/source policy, bounded results and provenance,
  # operation and session lifecycle, budgets and one-use action approvals.
  module Browser
  end
end
