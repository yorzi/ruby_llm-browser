# frozen_string_literal: true

abort "Use bin/check-browser" unless ENV["BROWSER_TEST"] == "1"
require "spec_helper"
require_relative "../dev/workbench"
require "capybara/rspec"
require "selenium-webdriver"

# Restrict both the driver probe and the application server to loopback.
module LoopbackPortProbe
  def free?(port)
    TCPServer.open("127.0.0.1", port) { true }
  rescue Errno::EADDRINUSE
    false
  end
end
Selenium::WebDriver::PortProber.singleton_class.prepend(LoopbackPortProbe)
WebMock.disable_net_connect!(allow_localhost: true)
Capybara.app = BrowserWorkbench.new
Capybara.server = :puma, { Silent: true }
Capybara.server_host = "127.0.0.1"
Capybara.default_max_wait_time = 5
Capybara.save_path = ENV.fetch("BROWSER_ARTIFACTS")
Capybara.register_driver :offline_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --window-size=1440,1000 --disable-background-networking --disable-dev-shm-usage].each { |arg| options.add_argument(arg) }
  options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  # Explicit path avoids driver downloads during a test run.
  service = Selenium::WebDriver::Service.chrome(path: ENV["CHROMEDRIVER"]) if ENV["CHROMEDRIVER"]
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, **(service ? { service: service } : {}))
end
Capybara.default_driver = :offline_chrome

RSpec.configure do |config|
  config.after(:each, type: :feature) do |example|
    begin
      session = Capybara.current_session
      if !example.exception && session.has_css?("#result-title", wait: 0)
        session.find("body").scroll_to(session.find("#result-title"), align: :top)
      end
      name = example.description.gsub(/[^a-zA-Z0-9_-]/, "_")
      page.save_screenshot(File.join(Capybara.save_path, "#{name}-#{example.exception ? 'failed' : 'passed'}.png"))
    rescue StandardError => error
      raise unless example.exception

      warn "Screenshot unavailable: #{error.class}: #{error.message}"
    ensure
      session&.driver&.quit
    end
  end
end
