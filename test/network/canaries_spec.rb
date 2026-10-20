# frozen_string_literal: true

require_relative "../browser_helper"
require "json"

RSpec.describe "offline network canary calibration", type: :feature do
  let(:probe) { Capybara.app.network_probe }
  let(:case_id) { probe.new_case }
  let(:kinds) { %w[fetch frame image popup script websocket worker] }

  def probe_path(action, target: "cross")
    "/network-probe/#{case_id}/#{action}?target=#{target}"
  end

  def wait_for_hits(expected)
    Selenium::WebDriver::Wait.new(timeout: 5).until { probe.hits(case_id).keys.sort == expected.sort }
    expect(probe.hits(case_id).keys).to match_array(expected)
  ensure
    File.write(File.join(Capybara.save_path, "#{case_id}.json"), JSON.pretty_generate(
      mode: "offline_canary_calibration", qualified: false,
      scenario: RSpec.current_example.description, case_id: case_id,
      chrome: page.driver.browser.capabilities.browser_version,
      expected_received: expected.sort, received: probe.hits(case_id)
    ))
  end

  it "receives every same-origin canary in an unrestricted browser" do
    visit probe_path("page", target: "same")
    click_button "Send probes"
    wait_for_hits(kinds)
    expect(page.driver.browser.window_handles.size).to eq(2)
  end

  it "detects every cross-origin leak in an unrestricted browser" do
    visit probe_path("page")
    click_button "Send probes"
    wait_for_hits(kinds)
    expect(page).to have_css("#sent", text: "All seven request paths attempted")
  end

  it "observes an image denial without mistaking other leaks for isolation" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit probe_path("page")
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*/network-probe/#{case_id}/hit/image" ])
    find_button("Send probes").send_keys(:enter)
    wait_for_hits(kinds - [ "image" ])
    expect(page.evaluate_script("document.querySelector('#canary-image').complete")).to be(true)
    expect(page.evaluate_script("document.querySelector('#canary-image').naturalWidth")).to eq(0)
    expect(probe.hits(case_id)).not_to have_key("image")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end

  it "reads the redirected final URL from Chrome rather than copying the requested URL" do
    visit probe_path("page")
    click_link "Follow redirect"
    expect(page).to have_title("Canary received: redirect")
    expect(URI(page.current_url).host).to eq("localhost")
    expect(URI(page.current_url).path).to eq("/network-probe/#{case_id}/hit/redirect")
    wait_for_hits([ "redirect" ])
  end
end
