# frozen_string_literal: true

module BrowserSpecSupport
  # A {RubyLLM::Browser::FakeBackend} that runs a callback while a session is live, so a
  # spec can cancel an operation (or fence it) between provider calls.
  class CancellingBackend < RubyLLM::Browser::FakeBackend
    def initialize(on_observe: nil, **options)
      super(**options)
      @on_observe = on_observe
    end

    def observe(session, instruction:, operation:, now:)
      @on_observe&.call(operation)
      super
    end
  end
end
