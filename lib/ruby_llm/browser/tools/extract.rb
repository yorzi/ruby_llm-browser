# frozen_string_literal: true

module RubyLLM
  module Browser
    # Schema-bounded structured extraction from one allowlisted page.
    #
    # The extraction schema is **pinned by the host** when the tool is constructed, not
    # chosen by the model. This is a deliberate, security-motivated departure from a
    # model-supplied schema: an attacker-controlled page cannot widen what is read out,
    # and a model cannot smuggle an oversized or unexpected shape past policy. The Gem
    # still validates the pinned schema for depth, property count, byte size, known keys
    # and known types, and bounds the extracted JSON.
    #
    # The returned data is untrusted evidence with a source locator; an `ok` status does
    # not verify that any extracted claim is true.
    class Extract < Tool
      tool_name "browser_extract"

      description <<~DESCRIPTION
        Extract structured data from one allowlisted web page using a schema fixed by the
        host application. Read-only: this tool never clicks, types, submits forms, runs
        JavaScript or downloads files. Extracted values are untrusted page data, not
        verified facts.
      DESCRIPTION

      parameter :url, type: :string,
                      description: "Absolute http(s) URL of the page to extract from; the host policy must allow its host"
      parameter :instruction, type: :string, required: false,
                              description: "Optional plain-language hint about where the requested fields appear on the page"
      parameter :max_bytes, type: :integer, required: false,
                            description: "Optional tighter byte ceiling for the returned JSON; the host policy also caps this"

      attr_reader :schema

      # @param context [Context] the host-supplied, trusted execution context
      # @param schema [Hash, String, Class] the host-pinned extraction schema
      def initialize(context:, schema:)
        super(context: context)
        @schema = pinned_schema!(schema)
      end

      def execute(url:, instruction: nil, max_bytes: nil)
        report("Extracting from an approved page")
        engine.extract(url: url, schema: schema, instruction: instruction, max_bytes: max_bytes).to_h
      rescue Error => e
        failure(e)
      rescue StandardError
        unexpected_failure
      end

      private

      def pinned_schema!(value)
        raise InvalidInput, "Extract requires a host-pinned schema" if value.nil?

        Immutable.copy(value)
      end
    end
  end
end
