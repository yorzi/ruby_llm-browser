# frozen_string_literal: true

module BrowserSpecSupport
  # Deterministic DNS resolver so security specs never depend on real resolution.
  class FakeResolver
    def initialize(map = {})
      @map = map
    end

    def getaddresses(host)
      addresses = @map[host]
      raise Resolv::ResolvError, host if addresses.nil?

      addresses
    end
  end
end
