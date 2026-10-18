# frozen_string_literal: true

module RubyLLM
  module Browser
    # Read-only configuration diagnostics for an offline or live backend.
    #
    # The Doctor never makes a network call, never starts a session and never prints a
    # credential. Common checks report RubyLLM compatibility and backend capabilities.
    # Only Stagehand backends inspect Stagehand's SDK and environment. FakeBackend
    # checks do not load the SDK or inspect provider credentials. A local pass never
    # qualifies a provider's actual guarantees. A `:fail` check blocks use.
    #
    #   report = RubyLLM::Browser::Doctor.new(backend: backend).report
    #   raise report[:summary] unless report[:ok]
    class Doctor
      STATUSES = %i[pass warn info fail].freeze

      attr_reader :backend, :env

      # @param backend [Backend, nil]
      # @param env [Hash] environment to inspect; injectable for tests
      def initialize(backend: nil, env: ENV)
        @backend = backend
        @env = env
      end

      # @return [Hash] `{ mode:, ok:, summary:, checks: [...] }`, safe to log.
      #   Mode is `:offline` for FakeBackend in fake mode, `:unconfigured` without
      #   a backend, and `:live` otherwise. Existing report keys remain available.
      def report
        checks = [ ruby_llm_check, egress_check, local_binary_check, custom_headers_check ]
        checks.concat([ stagehand_check, base_url_check, credentials_check ]) if backend.is_a?(StagehandBackend)
        checks.compact!
        {
          mode: mode,
          ok: checks.none? { |check| check[:status] == :fail },
          summary: summary_for(checks),
          checks: checks
        }
      end

      def ok? = report[:ok]

      private

      def mode
        return :unconfigured unless backend
        return :offline if backend.is_a?(FakeBackend) && backend.capabilities.server_mode == :fake

        :live
      end

      def ruby_llm_check
        version = Gem::Version.new(RubyLLM::VERSION)
        required = Gem::Version.new("2.0.0")
        ceiling = Gem::Version.new("3.0.0")
        if version >= required && version < ceiling
          check(:ruby_llm, :pass, "RubyLLM #{RubyLLM::VERSION} is within >= 2.0, < 3")
        else
          check(:ruby_llm, :fail, "RubyLLM #{RubyLLM::VERSION} is outside the supported range >= 2.0, < 3")
        end
      rescue StandardError => e
        check(:ruby_llm, :warn, "could not determine the RubyLLM version: #{e.class}")
      end

      def stagehand_check
        require "stagehand/version"
        unless Gem::Requirement.new("~> 3.21.0").satisfied_by?(Gem::Version.new(Stagehand::VERSION))
          return check(:stagehand, :fail, "Stagehand version is outside the tested 3.21.x series")
        end
        check(:stagehand, :pass, "stagehand #{Stagehand::VERSION} is available")
      rescue LoadError
        check(:stagehand, :warn, "the stagehand SDK is not installed; only fake backends can start")
      end

      def egress_check
        return check(:egress_isolation, :fail, "no backend was supplied") unless backend

        capabilities = backend.capabilities
        if backend.is_a?(StagehandBackend)
          return check(:egress_isolation, :fail,
                       "Stagehand backend is unsupported until provider egress and cleanup are qualified")
        end
        if capabilities.enforced_egress?
          detail = if mode == :offline
            "FakeBackend performs no network I/O; live egress is not verified"
          else
            "the backend asserts enforced, browser-side egress isolation"
          end
          check(:egress_isolation, :pass, detail)
        else
          check(:egress_isolation, :fail,
                "the backend does not assert enforced egress isolation; live sessions are refused")
        end
      end

      def local_binary_check
        return nil unless backend&.capabilities&.local_mode?

        if backend.capabilities.local_binary_pinned?
          check(:local_binary, :pass, "local mode uses a host-pinned server binary or version")
        else
          check(:local_binary, :fail,
                "local mode has no host-pinned #{StagehandBackend::PINNED_BINARY_ENV} or " \
                "#{StagehandBackend::PINNED_VERSION_ENV}; the SDK would download a binary")
        end
      end

      def custom_headers_check
        return nil unless backend&.capabilities&.custom_headers_present?

        if backend.capabilities.custom_headers_approved?
          check(:custom_headers, :pass, "#{StagehandBackend::CUSTOM_HEADERS_ENV} is set and host-approved")
        else
          check(:custom_headers, :fail,
                "#{StagehandBackend::CUSTOM_HEADERS_ENV} is set but not host-approved; the SDK always merges it")
        end
      end

      def base_url_check
        present = StagehandBackend::ENV_OVERRIDE_KEYS.select { |key| !env[key].to_s.empty? }
        return nil if present.empty?

        check(:base_url_override, :warn,
              "#{present.join(", ")} set; the adapter passes an explicit base_url so the override is ignored")
      end

      def credentials_check
        missing = %w[BROWSERBASE_API_KEY MODEL_API_KEY].reject { |key| !env[key].to_s.empty? }
        return check(:credentials, :info, "both provider credentials are present in the environment") if missing.empty?

        check(:credentials, :warn, "#{missing.join(", ")} not set in the environment")
      end

      def check(name, status, detail)
        raise ArgumentError, "unknown status #{status.inspect}" unless STATUSES.include?(status)

        { name: name, status: status, detail: detail }
      end

      def summary_for(checks)
        failed = checks.select { |check| check[:status] == :fail }
        return "configuration checks passed; live provider guarantees are not verified" if failed.empty?

        "blocked: #{failed.map { |check| check[:name] }.join(", ")}"
      end
    end
  end
end
