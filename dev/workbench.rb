# frozen_string_literal: true

# Development fixture only. No provider credentials, database, or live browser backend.
require "ruby_llm/browser"
require "rack"
require "cgi"
require "securerandom"

class BrowserWorkbench
  SCHEMA = { "type" => "object", "properties" => { "title" => { "type" => "string" } },
             "required" => [ "title" ], "additionalProperties" => false }.freeze
  URL = "https://docs.example.com/"
  RESOLVER = Object.new
  def RESOLVER.getaddresses(_host) = [ "93.184.216.34" ]

  def initialize
    @token = SecureRandom.hex(32)
  end

  def call(env)
    request = Rack::Request.new(env)
    return response(403, "Loopback only") unless %w[127.0.0.1 localhost ::1].include?(request.host)
    return response(404, "Not found") unless request.path == "/"
    return response(405, "Method not allowed") unless %w[GET POST].include?(request.request_method)

    result = nil
    url = URL
    if request.post?
      return response(403, "Invalid form token") unless request.params["token"] == @token

      url = request.params.fetch("url", URL).to_s
      result = run(request.params["operation"], url)
    end
    response(200, render(url, result))
  end

  private

  def run(operation, url)
    backend = RubyLLM::Browser::FakeBackend.new
    context = RubyLLM::Browser::Context.new(
      actor_id: "fixture-actor", run_id: "fixture-run", backend: backend,
      source_policy: RubyLLM::Browser::Policy.new(allowed_hosts: [ "docs.example.com" ], resolver: RESOLVER),
      operation_store: RubyLLM::Browser::InMemoryOperationStore.new
    )
    inspect, extract = RubyLLM::Browser.tools(context: context, schema: SCHEMA)
    data = case operation
    when "inspect" then inspect.call(url: url)
    when "extract" then extract.call(url: url)
    when "doctor" then RubyLLM::Browser::Doctor.new(backend: backend, env: {}).report
    when "stagehand_doctor"
      stagehand = RubyLLM::Browser::StagehandBackend.new(
        browserbase_api_key: "fixture-not-a-real-key", model_api_key: "fixture-not-a-real-key",
        model_name: "fixture-model", env: {}
      )
      RubyLLM::Browser::Doctor.new(backend: stagehand, env: {}).report
    else { status: "error", error: { code: "INVALID_INPUT" } }
    end
    { data: data, starts: backend.call_count(:start), closes: backend.call_count(:end_session) }
  end

  def response(status, body)
    [ status, { "content-type" => "text/html; charset=utf-8", "cache-control" => "no-store",
                "content-security-policy" => "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'" }, [ body ] ]
  end

  def escape(value) = CGI.escapeHTML(value.to_s)

  def render(url, result)
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
      <title>RubyLLM Browser · Offline workbench</title>
      <style>
      * { box-sizing: border-box; } body { margin: 0; padding: 24px; background: #f5f6f8; color: #172033; font: 16px/1.6 system-ui, sans-serif; }
      main { max-width: 900px; margin: 32px auto; } section { background: white; padding: 24px; border: 1px solid #d4d9e2; border-radius: 12px; margin: 24px 0; }
      h1 { line-height: 1.2; } label { display: block; font-weight: 600; } input { width: 100%; padding: 12px; margin: 8px 0 16px; font: inherit; }
      button { font: inherit; background: #263d89; color: white; border: 0; border-radius: 6px; padding: 12px 18px; margin: 4px; cursor: pointer; }
      :focus-visible { outline: 3px solid #cf6800; outline-offset: 3px; } pre { white-space: pre-wrap; overflow-wrap: anywhere; font-size: 14px; }
      code { overflow-wrap: anywhere; } .badge { color: #284d3a; font-weight: 700; } @media(max-width: 480px) { body { padding: 12px; } section { padding: 16px; } button { width: 100%; margin: 4px 0; } }
      </style></head><body><main>
      <p class="badge">Development fixture · offline only</p><h1>RubyLLM Browser workbench</h1>
      <p>Inspect candidates, extract a pinned title, or check configuration. All data comes from FakeBackend. No live page is loaded.</p>
      <section aria-labelledby="tools"><h2 id="tools">Read-only tools</h2>
      <p>browser_inspect · browser_extract</p>
      <form method="post" action="/"><input type="hidden" name="token" value="#{@token}">
      <label for="url">Page URL</label><input id="url" type="text" name="url" value="#{escape(url)}" required>
      <button name="operation" value="inspect">Inspect</button><button name="operation" value="extract">Extract</button>
      <button name="operation" value="doctor">Run Doctor</button>
      <button name="operation" value="stagehand_doctor">Check Stagehand</button></form>
      <p>Allowed host: <code>docs.example.com</code>. Try another host to inspect a denial.</p></section>
      #{result_html(result)}
      <p>Fixture results verify application wiring. They do not qualify provider egress, cleanup, TTL, or billing.</p>
      </main></body></html>
    HTML
  end

  def result_html(result)
    return "" unless result

    data = result.fetch(:data)
    status = data[:status] || (data[:ok] ? "configuration passed" : "configuration blocked")
    <<~HTML
      <section aria-labelledby="result-title" aria-live="polite"><h2 id="result-title">Result</h2>
      <p>Status: <output id="status">#{escape(status)}</output></p>
      <p id="dispatch">Fake session starts: #{result[:starts]} · Confirmed closes: #{result[:closes]}</p>
      <pre id="result">#{escape(JSON.pretty_generate(data))}</pre></section>
    HTML
  end
end
