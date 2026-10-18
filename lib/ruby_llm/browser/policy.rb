# frozen_string_literal: true

require "json"
require "json_schemer"

module RubyLLM
  module Browser
    # The host's source, schema, action and egress policy.
    #
    # Policy is composed by the host application and enforced by the Gem. It never
    # infers permissions from model arguments or page text, and it fails closed: an
    # unknown host, schema, action or an unqualified backend stops the operation.
    class Policy
      # JSON Schema keys this Gem accepts inside an extraction schema.
      SCHEMA_KEYS = %w[
        type description properties required items enum
        additionalProperties title minimum maximum
        minLength maxLength minItems maxItems
        format default
      ].freeze

      ALLOWED_SCHEMA_TYPES = %w[object array string integer number boolean null].freeze

      # Action methods an approved Act may use. There is no keypress/execute/download and
      # no arbitrary JavaScript.
      DEFAULT_ACTION_METHODS = %w[click fill press select_option check uncheck hover].freeze

      # Sensitive operations are refused even with a broad host approval.
      DEFAULT_FORBIDDEN_ACTIONS = [
        /\b(?:purchase|buy|checkout|pay(?:ment)?|place[-_ ]?order|subscribe|billing)\b/i,
        /\b(?:post|publish|tweet|toot|comment|reply|send(?:[-\s]?message)?|submit|share)\b/i,
        /\b(?:delete|destroy|remove|deactivate|close[-_ ]?account|cancel[-_ ]?account|unsubscribe)\b/i,
        /\b(?:password|passwd|credential|api[-_ ]?key|secret|credit[-_ ]?card|cvv|ssn|passport)\b/i,
        /\b(?:sign[-\s]?in|log[-\s]?in|log[-\s]?out|authenticate|sign[-\s]?up|register|2fa|otp)\b/i,
        /\b(?:transfer|withdraw|refund|donate)\b/i
      ].freeze

      DEFAULT_MAX_SCHEMA_DEPTH = 8
      DEFAULT_MAX_SCHEMA_PROPERTIES = 64
      DEFAULT_MAX_SCHEMA_BYTES = 16_384

      attr_reader :allowed_hosts, :allowed_schemes, :allowed_ports, :max_result_bytes,
                  :allowed_action_methods, :forbidden_action_patterns,
                  :max_schema_depth, :max_schema_properties, :max_schema_bytes

      def initialize(allowed_hosts:, allowed_schemes: UrlGuard::DEFAULT_SCHEMES,
                     allowed_ports: UrlGuard::DEFAULT_PORTS, verify_dns: true, resolver: nil,
                     max_result_bytes: nil,
                     allowed_action_methods: DEFAULT_ACTION_METHODS,
                     forbidden_action_patterns: DEFAULT_FORBIDDEN_ACTIONS,
                     max_schema_depth: DEFAULT_MAX_SCHEMA_DEPTH,
                     max_schema_properties: DEFAULT_MAX_SCHEMA_PROPERTIES,
                     max_schema_bytes: DEFAULT_MAX_SCHEMA_BYTES)
        @url_guard = UrlGuard.new(
          allowed_hosts: allowed_hosts, allowed_schemes: allowed_schemes,
          allowed_ports: allowed_ports, verify_dns: verify_dns, resolver: resolver
        )
        @allowed_hosts = @url_guard.allowed_hosts
        @allowed_schemes = @url_guard.allowed_schemes
        @allowed_ports = @url_guard.allowed_ports
        @max_result_bytes = positive_integer!(max_result_bytes || RubyLLM::Browser.configuration.max_result_bytes, :max_result_bytes)
        @allowed_action_methods = Immutable.copy(normalize_action_methods!(allowed_action_methods))
        @forbidden_action_patterns = (DEFAULT_FORBIDDEN_ACTIONS + Array(forbidden_action_patterns)).uniq.map do |pattern|
          raise InvalidInput, "forbidden actions must be regexps" unless pattern.is_a?(Regexp)

          pattern
        end.freeze
        @max_schema_depth = positive_integer!(max_schema_depth, :max_schema_depth)
        @max_schema_properties = positive_integer!(max_schema_properties, :max_schema_properties)
        @max_schema_bytes = positive_integer!(max_schema_bytes, :max_schema_bytes)
        freeze
      end

      # Authorizes and normalizes a destination URL.
      #
      # @return [URI::Generic]
      # @raise [InvalidInput] malformed or ambiguous URL
      # @raise [NotAuthorized] policy denial
      def authorize_destination!(url, actor_id: nil)
        @url_guard.authorize!(url)
      end

      # Validates a model-supplied extraction schema: an object schema, bounded in depth,
      # properties and bytes, using only known keys and types.
      #
      # @return [Hash] the schema (JSON string keys)
      def authorize_schema!(schema)
        schema = coerce_schema!(schema)
        raise InvalidInput, "extraction schema must be an object schema" unless schema.is_a?(Hash)
        json = Redactor.canonical_json(schema)
        raise InvalidInput, "extraction schema is too large" if json.bytesize > max_schema_bytes
        raise InvalidInput, "extraction schema must be an object schema" unless schema["type"] == "object"

        validate_schema_node!(schema, depth: 1)
        unless JSONSchemer.valid_schema?(schema)
          raise InvalidInput, "extraction schema is malformed"
        end
        properties = schema["properties"] || {}
        if properties.size > max_schema_properties
          raise InvalidInput, "extraction schema has too many properties"
        end

        Immutable.copy(schema)
      rescue JSON::GeneratorError, JSON::NestingError, SystemStackError
        raise InvalidInput, "extraction schema is not bounded JSON"
      end

      # Rejects provider data that does not satisfy the host's JSON Schema.
      def authorize_extraction!(data, schema:)
        raise ProviderError, "browser extraction did not match the host schema" unless JSONSchemer.schema(schema).valid?(data)

        data
      end

      # Redacts and bounds arbitrary extraction/observation data.
      #
      # @return [Array(Object, Boolean)] bounded data and truncation flag
      def authorize_result!(data, max_bytes: nil, secrets: [])
        Redactor.bound(data, max_bytes: [ max_bytes || max_result_bytes, max_result_bytes ].min, secrets: secrets)
      end

      # Validates one observed/approved action hash.
      #
      # @return [Hash] the normalized action (`description`, `method`, `selector`, `arguments`)
      def authorize_action!(action)
        action = symbolize_action!(action)
        method = action.fetch("method", nil)&.to_s&.downcase
        selector = action["selector"].to_s
        description = action["description"].to_s
        arguments = Array(action["arguments"]).map(&:to_s)

        raise InvalidInput, "action method is required" if method.to_s.empty?
        raise InvalidInput, "action selector is required" if selector.empty?
        unless allowed_action_methods.include?(method)
          raise NotAuthorized, "action method #{method.inspect} is not allowed"
        end

        haystack = ([ description, selector ] + arguments).join(" ")
        if forbidden_action_patterns.any? { |pattern| pattern.match?(haystack) }
          raise NotAuthorized, "action is outside the allowed, non-sensitive set"
        end

        {
          "description" => description.empty? ? "#{method} #{selector}" : description,
          "method" => method,
          "selector" => selector,
          "arguments" => arguments
        }
      end

      # True when a backend proves the egress isolation this Gem requires.
      def egress_qualified?(capabilities)
        return false unless capabilities.is_a?(Capabilities)
        return false unless capabilities.enforced_egress?
        return false if capabilities.local_mode? && !capabilities.local_binary_pinned?
        return false if capabilities.custom_headers_present? && !capabilities.custom_headers_approved?

        true
      end

      # Raises unless the backend is egress-qualified. Called before any session starts.
      def authorize_egress!(capabilities)
        return true if egress_qualified?(capabilities)

        raise UnsupportedSecurityCapability, egress_failure_reason(capabilities)
      end

      def to_h
        {
          allowed_hosts: allowed_hosts,
          allowed_schemes: allowed_schemes,
          allowed_ports: allowed_ports,
          max_result_bytes: max_result_bytes,
          allowed_action_methods: allowed_action_methods,
          max_schema_depth: max_schema_depth
        }
      end

      def digest = Redactor.digest(to_h)

      private

      def egress_failure_reason(capabilities)
        return "backend did not report capabilities" unless capabilities.is_a?(Capabilities)

        reasons = []
        reasons << "browser egress isolation is not enforced" unless capabilities.enforced_egress?
        if capabilities.local_mode? && !capabilities.local_binary_pinned?
          reasons << "local mode requires a host-pinned server binary"
        end
        if capabilities.custom_headers_present? && !capabilities.custom_headers_approved?
          reasons << "STAGEHAND_CUSTOM_HEADERS is set but not host-approved"
        end
        "backend cannot enforce egress isolation: #{reasons.join("; ")}"
      end

      def coerce_schema!(schema)
        case schema
        when Hash
          stringify_keys(schema)
        when String
          parse_schema_json!(schema)
        when Class
          if schema.respond_to?(:to_json_schema)
            return stringify_keys(schema.to_json_schema)
          end
          if schema.instance_methods.include?(:to_json_schema)
            return stringify_keys(schema.new.to_json_schema)
          end
          raise InvalidInput, "unsupported schema class"
        else
          if schema.respond_to?(:to_json_schema)
            stringify_keys(schema.to_json_schema)
          else
            raise InvalidInput, "extraction schema must be a Hash or JSON object string"
          end
        end
      end

      def parse_schema_json!(string)
        raise InvalidInput, "extraction schema is too large" if string.bytesize > max_schema_bytes

        parsed = JSON.parse(string)
        raise InvalidInput, "extraction schema must be a JSON object" unless parsed.is_a?(Hash)

        stringify_keys(parsed)
      rescue JSON::ParserError
        raise InvalidInput, "extraction schema is not valid JSON", cause: nil
      end

      def validate_schema_node!(node, depth:)
        return unless node.is_a?(Hash) || node.is_a?(Array)

        if depth > max_schema_depth
          raise InvalidInput, "extraction schema is nested too deeply"
        end

        case node
        when Array
          node.each { |item| validate_schema_node!(item, depth: depth + 1) }
        when Hash
          node.each do |key, value|
            name = key.to_s
            unless SCHEMA_KEYS.include?(name)
              raise InvalidInput, "unsupported schema key #{name.inspect}"
            end
            validate_schema_type!(value) if name == "type"
            if name == "properties"
              # Values are schemas; property names themselves are arbitrary.
              value.each_value { |subschema| validate_schema_node!(subschema, depth: depth + 1) } if value.is_a?(Hash)
            elsif name == "items" || name == "additionalProperties"
              validate_schema_node!(value, depth: depth + 1)
            end
          end
        end
      end

      def validate_schema_type!(value)
        types = Array(value).map(&:to_s)
        invalid = types - ALLOWED_SCHEMA_TYPES
        raise InvalidInput, "unsupported schema type #{invalid.inspect}" if invalid.any?
      end

      def symbolize_action!(action)
        raise InvalidInput, "action must be a Hash" unless action.is_a?(Hash)

        action.each_with_object({}) { |(key, value), result| result[key.to_s] = value }
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, nested), result| result[key.to_s] = stringify_keys(nested) }
        when Array
          value.map { |item| stringify_keys(item) }
        else
          value
        end
      end

      def normalize_action_methods!(methods)
        normalized = Array(methods).map { |method| method.to_s.downcase }
        raise InvalidInput, "allowed_action_methods must not be empty" if normalized.empty?
        unless (normalized - DEFAULT_ACTION_METHODS).empty?
          raise InvalidInput, "only supported non-script action methods are allowed"
        end

        normalized.uniq
      end

      def positive_integer!(value, name)
        raise InvalidInput, "#{name} must be a positive integer" unless value.is_a?(Integer) && value.positive?

        value
      end
    end
  end
end
