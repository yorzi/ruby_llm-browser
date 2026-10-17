#!/usr/bin/env ruby
# frozen_string_literal: true

# Offline demo of the read-only tools over the fake backend: no network, no API key.
#
#   bundle exec ruby examples/plain_ruby.rb
require "ruby_llm/browser"

# A deterministic resolver keeps the demo offline; production uses real DNS.
class DemoResolver
  def getaddresses(_host) = [ "93.184.216.34" ]
end

policy = RubyLLM::Browser::Policy.new(
  allowed_hosts: [ "docs.example.com" ], resolver: DemoResolver.new
)
context = RubyLLM::Browser::Context.new(
  actor_id: "demo-actor",
  run_id: "demo-run",
  source_policy: policy,
  backend: RubyLLM::Browser::FakeBackend.new,
  operation_store: RubyLLM::Browser::InMemoryOperationStore.new,
  budget: RubyLLM::Browser::Budget.new(max_seconds: 30, max_steps: 6)
)

inspect = RubyLLM::Browser::Inspect.new(context: context)
puts "Inspect: #{inspect.execute(url: "https://docs.example.com/")}"

schema = { "type" => "object", "properties" => { "title" => { "type" => "string" } } }
extract = RubyLLM::Browser::Extract.new(context: context, schema: schema)
puts "Extract: #{extract.execute(url: "https://docs.example.com/", instruction: "the title")}"

blocked = inspect.execute(url: "http://169.254.169.254/latest/meta-data")
puts "Blocked: #{blocked[:error][:code]}"
