# frozen_string_literal: true

require "spec_helper"
require_relative "../../dev/workbench"

RSpec.describe "workbench network canaries" do
  let(:app) { BrowserWorkbench.new(enable_network_probes: true) }
  let(:client) { Rack::MockRequest.new(app) }
  let(:case_id) { app.network_probe.new_case }
  let(:prefix) { "http://127.0.0.1:4024/network-probe/#{case_id}" }

  it "keeps probes unavailable in the normal workbench" do
    normal = Rack::MockRequest.new(BrowserWorkbench.new)
    expect(normal.get("#{prefix}/page").status).to eq(404)
  end

  it "requires a case issued in process and loopback Host" do
    expect(client.get("http://127.0.0.1:4024/network-probe/unknown/page").status).to eq(404)
    expect(client.get(prefix.sub("127.0.0.1", "other.example") + "/page").status).to eq(403)
    expect(client.post("#{prefix}/hit/image").status).to eq(405)
    expect(app.network_probe.hits(case_id)).to be_empty
  end

  it "records only received requests from the named case" do
    other_case = app.network_probe.new_case
    expect(client.get("#{prefix}/hit/image").status).to eq(200)
    expect(client.get("#{prefix}/hit/websocket").status).to eq(400)
    expect(client.get("#{prefix}/hit/websocket", "HTTP_UPGRADE" => "websocket",
                      "HTTP_CONNECTION" => "keep-alive, Upgrade").status).to eq(426)
    expect(client.get("#{prefix}/hit/unknown").status).to eq(404)

    expect(app.network_probe.hits(case_id)).to eq("image" => 1, "websocket" => 1)
    expect(app.network_probe.hits(other_case)).to be_empty
  end

  it "pins both target origins to loopback without accepting a supplied destination" do
    response = client.get("#{prefix}/page?target=https://outside.example/")
    expect(response.status).to eq(400)
    expect(client.get("#{prefix}/page?target=cross").body).to include("http://localhost:4024")
    expect(client.get("#{prefix}/page?target=same").body).to include("http://127.0.0.1:4024")
    expect(app.network_probe.hits(case_id)).to be_empty
  end

  it "redirects to the canary instead of recording the initial navigation as a hit" do
    response = client.get("#{prefix}/redirect?target=cross")
    expect(response.status).to eq(302)
    expect(response["location"]).to eq("http://localhost:4024/network-probe/#{case_id}/hit/redirect")
    expect(app.network_probe.hits(case_id)).to be_empty
  end

  it "bounds case storage and refuses evicted identities" do
    old = case_id
    16.times { app.network_probe.new_case }
    expect(client.get("http://127.0.0.1:4024/network-probe/#{old}/page").status).to eq(404)
  end
end
