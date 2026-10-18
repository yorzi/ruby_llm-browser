# frozen_string_literal: true

require "ipaddr"
require "resolv"
require "uri"

module RubyLLM
  module Browser
    # Normalizes and authorizes HTTP(S) destinations.
    #
    # This is a *local* defense. It rejects malformed and ambiguous URLs, unsupported
    # schemes, non-approved ports and any destination that is or resolves to a
    # loopback, private, link-local, multicast, documentation or cloud-metadata address.
    # It cannot control a remote browser's egress; {Policy} therefore also requires the
    # backend to prove enforced egress isolation before any session starts.
    class UrlGuard
      DEFAULT_SCHEMES = %w[http https].freeze
      DEFAULT_PORTS = [ 80, 443 ].freeze

      # IPv4 ranges that must never be reachable: "this network", private, CGNAT,
      # loopback, link-local (including the 169.254.169.254 metadata route), TEST-NET,
      # benchmark, multicast, reserved and broadcast.
      RESERVED_V4 = %w[
        0.0.0.0/8
        10.0.0.0/8
        100.64.0.0/10
        127.0.0.0/8
        169.254.0.0/16
        172.16.0.0/12
        192.0.0.0/24
        192.0.2.0/24
        192.88.99.0/24
        192.168.0.0/16
        198.18.0.0/15
        198.51.100.0/24
        203.0.113.0/24
        224.0.0.0/4
        240.0.0.0/4
        255.255.255.255/32
      ].freeze

      # IPv6 ranges that must never be reachable, including every IPv4-mapped form.
      RESERVED_V6 = %w[
        ::/128
        ::1/128
        ::ffff:0:0/96
        64:ff9b::/96
        100::/64
        2001:db8::/32
        fc00::/7
        fe80::/10
        ff00::/8
      ].freeze

      RESERVED_RANGES = (RESERVED_V4 + RESERVED_V6).map { |range| IPAddr.new(range) }.freeze

      # Hosts made only of digits (or IPv4-integer forms such as 0x7f, 0177) are
      # ambiguous IP encodings, not hostnames.
      NUMERIC_HOST = /\A(?:0[xX][0-9a-fA-F]+|\d+)\z/
      HEXY_HOST = /\A(?=[0-9a-fxX.]*\d)[0-9a-fxX.]+\z/
      CANONICAL_V4 = /\A\d{1,3}(?:\.\d{1,3}){3}\z/
      ALLOWLIST_ENTRY = /\A(?:\*\.)?[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/

      attr_reader :allowed_hosts, :allowed_schemes, :allowed_ports, :resolver

      # @param allowed_hosts [Array<String>] exact hosts or `*.example.com` patterns
      # @param verify_dns [Boolean] resolve hostnames and reject private answers
      # @param resolver [Object] a Resolv-like object responding to `getaddresses`
      def initialize(allowed_hosts:, allowed_schemes: DEFAULT_SCHEMES, allowed_ports: DEFAULT_PORTS,
                     verify_dns: true, resolver: nil)
        @allowed_hosts = Immutable.copy(normalize_allowlist!(allowed_hosts))
        @allowed_schemes = Immutable.copy(normalize_schemes!(allowed_schemes))
        @allowed_ports = Immutable.copy(normalize_ports!(allowed_ports))
        @verify_dns = verify_dns
        @resolver = resolver || Resolv
        freeze
      end

      def verify_dns? = @verify_dns

      # Normalizes +url+ and returns it, or raises.
      #
      # @return [URI::Generic] the normalized, frozen, fragment-free URL
      # @raise [InvalidInput] malformed, ambiguous or non-HTTP(S) input
      # @raise [NotAuthorized] a destination the host policy does not allow
      def authorize!(url)
        uri = coerce_uri!(url)
        scheme = uri.scheme.to_s.downcase
        unless allowed_schemes.include?(scheme)
          raise NotAuthorized, "scheme #{scheme.inspect} is not allowed"
        end

        raise NotAuthorized, "URLs with userinfo are not allowed" if uri.userinfo

        host = normalize_host!(uri)
        raise InvalidInput, "ambiguous IP literal address: #{host.inspect}" if ambiguous_ip?(host)

        unless host_allowed?(host)
          raise NotAuthorized, "host #{host.inspect} is not in the allowed source list"
        end

        ensure_public!(host)
        port = effective_port(uri)
        unless allowed_ports.include?(port)
          raise NotAuthorized, "port #{port} is not allowed"
        end

        build_uri(scheme, host, port, uri)
      end

      # True when the exact host (case-insensitive) matches an allowlist entry.
      def host_allowed?(host)
        allowed_hosts.any? { |pattern| host_matches?(pattern, host) }
      end

      # True for any IP in a reserved/private range. Non-IP input returns true so that
      # unparseable addresses fail closed.
      def private_address?(address)
        ip = IPAddr.new(address.to_s)
        RESERVED_RANGES.any? { |range| range.include?(ip) }
      rescue IPAddr::Error
        true
      end

      def to_h
        {
          allowed_hosts: allowed_hosts,
          allowed_schemes: allowed_schemes,
          allowed_ports: allowed_ports,
          verify_dns: @verify_dns
        }
      end

      private

      def coerce_uri!(url)
        uri =
          case url
          when URI::Generic then url
          when String then URI.parse(url)
          else raise InvalidInput, "url must be a String or URI"
          end
        uri = uri.dup
        raise InvalidInput, "url is missing a scheme and host" if uri.host.nil? || uri.scheme.nil?

        uri
      rescue URI::InvalidURIError
        raise InvalidInput, "url is not a valid URI", cause: nil
      end

      def normalize_host!(uri)
        host = (uri.hostname || uri.host).to_s.strip
        raise InvalidInput, "url is missing a host" if host.empty?
        raise InvalidInput, "internationalized hosts are not supported; use punycode" unless host.ascii_only?

        host.downcase.chomp(".")
      end

      def ambiguous_ip?(host)
        return true if host.match?(NUMERIC_HOST)
        return !host.match?(CANONICAL_V4) if host.match?(HEXY_HOST)

        false
      end

      def host_matches?(pattern, host)
        return host == pattern unless pattern.start_with?("*.")

        suffix = pattern.delete_prefix("*.")
        host.end_with?(".#{suffix}")
      end

      def effective_port(uri)
        uri.port || (uri.scheme.to_s.downcase == "https" ? 443 : 80)
      end

      def ensure_public!(host)
        addresses_for(host).each do |address|
          next unless private_address?(address)

          raise NotAuthorized, "host #{host.inspect} resolves to a non-public address"
        end
      end

      def addresses_for(host)
        return [ host ] if ip_literal?(host)

        resolved = resolver.getaddresses(host)
        raise NotAuthorized, "host #{host.inspect} did not resolve" if resolved.empty?

        resolved.map(&:to_s)
      rescue Resolv::ResolvError
        raise NotAuthorized, "host #{host.inspect} did not resolve"
      end

      def ip_literal?(host)
        IPAddr.new(host)
        true
      rescue IPAddr::Error
        false
      end

      def build_uri(scheme, host, port, uri)
        host_part = host.include?(":") ? "[#{host}]" : host
        default = (scheme == "http" && port == 80) || (scheme == "https" && port == 443)
        authority = default ? host_part : "#{host_part}:#{port}"
        path = uri.path.to_s.empty? ? "/" : uri.path
        query = uri.query
        normalized = URI.parse("#{scheme}://#{authority}#{path}#{query ? "?#{query}" : ""}")
        normalized.freeze
      rescue URI::InvalidURIError
        raise InvalidInput, "url is not a valid URI", cause: nil
      end

      def normalize_allowlist!(hosts)
        unless hosts.is_a?(Array) && hosts.any?
          raise InvalidInput, "allowed_hosts must be a non-empty Array of host patterns"
        end

        hosts.map do |entry|
          normalized = entry.to_s.strip.downcase.chomp(".")
          next normalized if ip_literal?(normalized)

          unless ALLOWLIST_ENTRY.match?(normalized)
            raise InvalidInput, "invalid allowlist entry: #{entry.inspect}"
          end

          normalized
        end.uniq
      end

      def normalize_schemes!(schemes)
        normalized = Array(schemes).map { |scheme| scheme.to_s.downcase }
        raise InvalidInput, "allowed_schemes must not be empty" if normalized.empty?

        unless normalized.all? { |scheme| DEFAULT_SCHEMES.include?(scheme) }
          raise InvalidInput, "only http and https schemes are supported"
        end

        normalized.uniq
      end

      def normalize_ports!(ports)
        normalized = Array(ports)
        unless normalized.all? { |port| port.is_a?(Integer) && port.between?(1, 65_535) }
          raise InvalidInput, "allowed_ports must be a list of valid port numbers"
        end

        normalized.uniq
      end
    end
  end
end
