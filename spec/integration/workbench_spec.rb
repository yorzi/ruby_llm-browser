# frozen_string_literal: true

require "spec_helper"
require_relative "../../dev/workbench"

RSpec.describe "offline development workbench" do
  let(:client) { Rack::MockRequest.new(BrowserWorkbench.new) }

  def submit(operation, url: BrowserWorkbench::URL)
    token = client.get("http://127.0.0.1/").body[/name="token" value="([^"]+)"/, 1]
    client.post("http://127.0.0.1/", params: { token: token, operation: operation, url: url })
  end

  it "exercises extraction with confirmed fake cleanup" do
    response = submit("extract")
    expect(response.status).to eq(200)
    expect(response.body).to include('id="status">ok', "Example", "Fake session starts: 1 · Confirmed closes: 1")
  end

  it "rejects disallowed destinations without starting a session" do
    response = submit("inspect", url: "https://blocked.example/")
    expect(response.body).to include("NOT_AUTHORIZED", "Fake session starts: 0")
  end

  it "escapes submitted text and prevents non-local or forged submissions" do
    response = submit("inspect", url: '\"><script>alert(1)</script>')
    expect(response.body).not_to include("<script>")
    expect(client.get("http://other.example/").status).to eq(403)
    expect(client.post("http://127.0.0.1/", params: { operation: "inspect" }).status).to eq(403)
  end
end
