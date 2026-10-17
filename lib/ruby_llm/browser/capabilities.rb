# frozen_string_literal: true

module RubyLLM
  module Browser
    # What a backend can actually guarantee.
    #
    # Capabilities are the Gem's fail-closed gate. Policy refuses to start a session
    # unless a backend claims *enforced* egress isolation; a URL allowlist in Ruby can
    # never substitute for it. Local mode needs a host-pinned server binary, and the
    # Stagehand SDK always merges +STAGEHAND_CUSTOM_HEADERS+, so those headers must be
    # host-approved before any session starts.
    class Capabilities
      # Supported egress-isolation postures.
      #
      # - `:enforced`   every initiated request stays within approved destinations and
      #                 public address ranges at connection time
      # - `:unverified` not proven; the Gem treats this as unusable for live sessions
      EGRESS_ISOLATION = %i[enforced unverified].freeze

      # Server/topology modes.
      SERVER_MODES = %i[fake remote local].freeze

      attr_reader :server_mode, :egress_isolation

      def initialize(server_mode: :remote, egress_isolation: :unverified,
                     local_binary_pinned: false, custom_headers_present: false,
                     custom_headers_approved: false, act_supported: false)
        @server_mode = symbolize!(server_mode, SERVER_MODES, :server_mode)
        @egress_isolation = symbolize!(egress_isolation, EGRESS_ISOLATION, :egress_isolation)
        @local_binary_pinned = !!local_binary_pinned
        @custom_headers_present = !!custom_headers_present
        @custom_headers_approved = !!custom_headers_approved
        @act_supported = !!act_supported
        freeze
      end

      def local_mode? = server_mode == :local
      def enforced_egress? = egress_isolation == :enforced
      def local_binary_pinned? = @local_binary_pinned
      def custom_headers_present? = @custom_headers_present
      def custom_headers_approved? = @custom_headers_approved
      def act_supported? = @act_supported

      def to_h
        {
          server_mode: server_mode,
          egress_isolation: egress_isolation,
          local_binary_pinned: @local_binary_pinned,
          custom_headers_present: @custom_headers_present,
          custom_headers_approved: @custom_headers_approved,
          act_supported: @act_supported
        }
      end

      def digest = Redactor.digest(to_h)

      def ==(other)
        other.is_a?(Capabilities) && to_h == other.to_h
      end
      alias eql? ==

      def hash = to_h.hash

      def inspect = "#<#{self.class} #{to_h.map { |k, v| "#{k}=#{v}" }.join(" ")}>"

      private

      def symbolize!(value, allowed, name)
        symbol = value.to_sym
        return symbol if allowed.include?(symbol)

        raise InvalidInput, "#{name} must be one of #{allowed.inspect}"
      end
    end
  end
end
