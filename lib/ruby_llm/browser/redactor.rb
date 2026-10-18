# frozen_string_literal: true

require "digest"
require "json"
require "uri"

module RubyLLM
  module Browser
    # Sanitization and bounding helpers for anything that could reach a model message,
    # tool result, log line or error.
    #
    # Page text, model output and provider metadata are untrusted. They are redacted by
    # key name, scrubbed of known secrets, stripped of DevTools URLs, and bounded by
    # size and depth before they leave a backend.
    module Redactor
      # The replacement for redacted values.
      REDACTED = "[REDACTED]"

      # JSON preview marker when a value is too large to return whole.
      TRUNCATED = "[TRUNCATED]"

      # Maximum nesting depth kept while redacting.
      MAX_DEPTH = 12

      # Keys whose values are always treated as secrets. Matching is case-insensitive
      # and applies to `snake_case`, `kebab-case` and `camelCase` spellings.
      SECRET_KEY = /
        api[-_]?key | apikey |
        access[-_]?token | refresh[-_]?token | id[-_]?token |
        client[-_]?secret | private[-_]?key |
        authorization | bearer |
        password | passwd | credential |
        cookie | set[-_]?cookie |
        secret | token |
        cdp[-_]?url | devtools |
        x[-_]bb[-_]api[-_]key | x[-_]model[-_]api[-_]key
      /xi

      # A DevTools WebSocket URL anywhere in a string. Full browser control, so it is
      # always removed.
      DEVTOOLS_URL = %r{ws{1,2}://[^\s"']*}i

      # Secrets shorter than this are not treated as replaceable literals; replacing
      # very short strings would corrupt ordinary text.
      MIN_LITERAL_SECRET = 8

      module_function

      # Returns a redacted, depth-bounded copy of +value+.
      #
      # @param value [Object]
      # @param secrets [Array<String>] exact secret values to remove from strings
      # @param max_depth [Integer] nesting depth at which content is replaced entirely
      def redact(value, secrets: [], depth: 0, max_depth: MAX_DEPTH)
        return REDACTED if depth > max_depth

        case value
        when Hash
          value.each_with_object({}) do |(key, nested), result|
            safe_key = scrub_string(key.to_s, secrets: secrets)
            result[safe_key] = secret_key?(key) ? REDACTED : redact(nested, secrets: secrets, depth: depth + 1, max_depth: max_depth)
          end
        when Array
          value.map { |item| redact(item, secrets: secrets, depth: depth + 1, max_depth: max_depth) }
        when String
          scrub_string(value, secrets: secrets)
        when Symbol
          scrub_string(value.to_s, secrets: secrets)
        else
          value
        end
      end

      # Redacts and then bounds +value+ to +max_bytes+ of JSON.
      #
      # @return [Array(Object, Boolean)] the bounded value and whether it was truncated
      def bound(value, max_bytes:, secrets: [])
        unless max_bytes.is_a?(Integer) && max_bytes.positive?
          raise InvalidInput, "max_bytes must be a positive integer"
        end
        redacted = redact(value, secrets: secrets)
        json = canonical_json(redacted)
        return [ redacted, false ] if json.bytesize <= max_bytes

        # Count encoded bytes, not characters: JSON escaping can expand a preview.
        envelope = { "truncated" => true, "preview" => "", "note" => TRUNCATED }
        return [ "", true ] if max_bytes < canonical_json(envelope).bytesize && max_bytes >= 2
        return [ 0, true ] if max_bytes == 1

        low = 0
        high = [ json.length, max_bytes ].min
        while low < high
          midpoint = (low + high + 1) / 2
          envelope["preview"] = json[0, midpoint]
          if canonical_json(envelope).bytesize <= max_bytes
            low = midpoint
          else
            high = midpoint - 1
          end
        end
        envelope["preview"] = json[0, low]
        [ envelope, true ]
      end

      # Stable JSON for digests: object keys sorted, no insignificant whitespace.
      def canonical_json(value)
        JSON.generate(sort_keys(value))
      end

      # SHA-256 hex digest of the canonical JSON of +value+.
      def digest(value)
        Digest::SHA256.hexdigest(canonical_json(value))
      end

      # True when a key name denotes a secret value.
      def secret_key?(key)
        SECRET_KEY.match?(key.to_s)
      end

      # Removes userinfo, fragments and credential-like query values from provenance.
      def url(value, secrets: [])
        uri = URI.parse(value.to_s)
        uri.userinfo = nil if uri.respond_to?(:userinfo=)
        uri.fragment = nil
        if uri.query
          uri.query = URI.encode_www_form(URI.decode_www_form(uri.query).map do |key, nested|
            [ key, secret_key?(key) ? REDACTED : nested ]
          end)
        end
        scrub_string(uri.to_s, secrets: secrets)
      rescue URI::Error, ArgumentError
        "[REDACTED URL]"
      end

      def sort_keys(value)
        case value
        when Hash
          value.keys.map(&:to_s).sort.to_h do |key|
            [ key, sort_keys(value.key?(key) ? value[key] : value[key.to_sym]) ]
          end
        when Array
          value.map { |item| sort_keys(item) }
        else
          value
        end
      end

      def scrub_string(string, secrets:)
        scrubbed = string.dup.force_encoding(Encoding::UTF_8).scrub
        (secrets || []).each do |secret|
          next if secret.to_s.length < MIN_LITERAL_SECRET

          scrubbed = scrubbed.gsub(secret.to_s, REDACTED)
        end
        scrubbed.gsub(DEVTOOLS_URL, REDACTED)
      end
    end
  end
end
