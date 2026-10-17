# frozen_string_literal: true

module BrowserSpecSupport
  # Minimal stand-ins for the Stagehand SDK response envelope, so the adapter specs can
  # inject a fake client without constructing real SDK models or touching the network.
  StagehandResponse = Struct.new(:data, :success)

  StagehandData = Struct.new(:session_id, :cdp_url, :result, keyword_init: true)
end
