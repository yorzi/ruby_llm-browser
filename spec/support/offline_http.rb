# frozen_string_literal: true

require "webmock/rspec"

# A mistaken SDK call must fail the test, never contact a paid provider.
WebMock.disable_net_connect!
