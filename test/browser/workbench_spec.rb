# frozen_string_literal: true

require_relative "../browser_helper"

RSpec.describe "offline workbench", type: :feature do
  it "inspects and extracts through the Ruby tools with confirmed cleanup" do
    visit "/"
    expect(page).to have_title("RubyLLM Browser · Offline workbench")
    click_button "Inspect", exact: true
    expect(page).to have_css("#status", text: "ok", exact_text: true)
    expect(page).to have_css("#result", text: "Open the documentation link")
    expect(page).to have_css("#dispatch", text: "Fake session starts: 1 · Confirmed closes: 1")
    click_button "Extract", exact: true
    expect(page).to have_css("#result", text: '"title": "Example"')
    expect(page).to have_css("#dispatch", text: "Fake session starts: 1 · Confirmed closes: 1")
  end

  it "denies a destination before dispatch and recovers using the keyboard on mobile" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit "/"
    expect(page.evaluate_script("window.innerWidth")).to eq(390)
    fill_in "Page URL", with: "https://blocked.example/"
    click_button "Extract", exact: true
    expect(page).to have_css("#result", text: "NOT_AUTHORIZED")
    expect(page).to have_css("#dispatch", text: "Fake session starts: 0")
    fill_in "Page URL", with: BrowserWorkbench::URL
    find_button("Extract", exact: true).send_keys(:enter)
    expect(page).to have_css("#status", text: "ok", exact_text: true)
    expect(page).to have_css("#result", text: "Example")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end

  it "shows offline diagnostics without starting a browser provider session" do
    visit "/"
    click_button "Run Doctor"
    expect(page).to have_css("#status", text: "configuration passed", exact_text: true)
    expect(page).to have_css("#result", text: "live provider guarantees are not verified")
    expect(page).to have_css("#result", text: '"mode": "offline"')
    expect(page).not_to have_css("#result", text: "BROWSERBASE_API_KEY")
    expect(page).to have_css("#dispatch", text: "Fake session starts: 0")
  end

  it "keeps Stagehand blocked even though the SDK is installed" do
    visit "/"
    click_button "Check Stagehand"
    expect(page).to have_css("#status", text: "configuration blocked", exact_text: true)
    expect(page).to have_css("#result", text: '"mode": "live"')
    expect(page).to have_css("#result", text: "Stagehand backend is unsupported")
    expect(page).not_to have_css("#result", text: "fixture-not-a-real-key")
    expect(page).to have_css("#dispatch", text: "Fake session starts: 0")
  end
end
