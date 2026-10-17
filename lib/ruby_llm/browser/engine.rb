# frozen_string_literal: true

module RubyLLM
  module Browser
    # Orchestrates one bounded browser operation.
    #
    # The engine enforces, in order: egress qualification (before anything remote),
    # destination policy, budget reservation and the actor concurrency slot, the
    # operation lifecycle, step/byte/time limits, result redaction and bounding, and a
    # best-effort cleanup that never reports unconfirmed closure as success.
    #
    # Pre-flight failures (policy, budget, input) raise a typed {Error}. Failures after a
    # session exists are returned as a {Result} with a typed status so the operation's
    # durable state is recorded first.
    class Engine
      Attempt = Struct.new(:operation, :session, :uri, keyword_init: true)

      attr_reader :context

      def initialize(context:)
        @context = context
      end

      # Read-only observation of an allowlisted page.
      def inspect(url:, instruction: nil, max_bytes: nil)
        max_bytes = optional_positive_integer!(max_bytes, :max_bytes)
        execute(url: url) do |attempt|
          attempt.operation = next_step(attempt.operation)
          observed = backend.observe(attempt.session, instruction: instruction,
                                     operation: attempt.operation, now: now)
          ok_result(
            attempt.operation, observed, session: attempt.session,
            locator: { "url" => current_url(attempt), "scope" => "observe" },
            max_bytes: max_bytes
          )
        end
      end

      # Schema-bounded extraction from an allowlisted page.
      def extract(url:, schema:, instruction: nil, max_bytes: nil)
        max_bytes = optional_positive_integer!(max_bytes, :max_bytes)
        validated = policy.authorize_schema!(schema)
        execute(url: url) do |attempt|
          attempt.operation = next_step(attempt.operation)
          data = backend.extract(attempt.session, schema: validated, instruction: instruction,
                                 operation: attempt.operation, now: now)
          ok_result(
            attempt.operation, data, session: attempt.session,
            locator: { "url" => current_url(attempt), "scope" => "extract",
                       "schema_digest" => Redactor.digest(validated) },
            max_bytes: max_bytes
          )
        end
      end

      # One human-approved action. Disabled unless an approval store is configured and an
      # active, exactly-bound, single-use approval exists.
      def act(url:, approval_id:, action:, page_revision: nil)
        normalized = policy.authorize_action!(action)
        require_approval_store!
        execute(url: url) do |attempt|
          ensure_no_redirect!(attempt)
          attempt.operation = next_step(attempt.operation)
          observed = backend.observe(attempt.session, instruction: nil,
                                     operation: attempt.operation, now: now)
          revision = page_revision || Approval.page_revision(observed)
          approval = consume_approval!(approval_id, attempt: attempt, action: normalized,
                                       page_revision: revision)
          attempt.operation = next_step(attempt.operation)
          data = backend.act(attempt.session, action: normalized, operation: attempt.operation, now: now)
          ok_result(
            attempt.operation, data, session: attempt.session,
            locator: { "url" => attempt.uri.to_s, "scope" => "act",
                       "approval_id" => approval.id, "action_digest" => approval.action_digest },
            max_bytes: nil
          )
        end
      end

      private

      def execute(url:)
        policy.authorize_egress!(capabilities)
        uri = policy.authorize_destination!(url, actor_id: context.actor_id)
        operation = reserve(uri)
        operation = transition(operation, :starting)

        session =
          begin
            backend.start(context: context, operation: operation, now: now)
          rescue SessionUnknown => e
            transition(operation, :unknown, error_code: e.code)
            return Result.failure(:unknown, error_code: e.code, message: e.message,
                                  operation_id: operation.id, final_url: uri.to_s)
          rescue ProviderError => e
            transition(operation, :closed, error_code: e.code)
            return Result.failure(:error, error_code: e.code, message: e.message,
                                  operation_id: operation.id, final_url: uri.to_s)
          end

        operation = transition(operation, :active, session_id: session.id)
        attempt = Attempt.new(operation: operation, session: session, uri: uri)

        outcome =
          begin
            attempt.operation = next_step(attempt.operation)
            attempt.session = navigate(attempt)
            yield attempt
          rescue Error => e
            failure_result(e, attempt)
          rescue StandardError => e
            failure_result(ProviderError.new("unexpected backend failure: #{e.class}"), attempt)
          end

        finish(attempt, outcome)
      end

      def reserve(uri)
        now = self.now
        operation = Operation.new(
          id: Operation.generate_id, actor_id: context.actor_id, run_id: context.run_id,
          budget: context.budget, state: :reserved, created_at: now, updated_at: now
        )
        store.reserve(operation)
      end

      # Records one provider round-trip, refusing once a limit is reached.
      def next_step(operation)
        timestamp = now
        raise BudgetExhausted, "operation wall-clock budget exhausted" if operation.expired?(timestamp)

        store.update(operation.consume_step!(now: timestamp))
      end

      def ok_result(operation, data, session:, locator:, max_bytes:)
        bounded, truncated = policy.authorize_result!(
          data, max_bytes: max_bytes || policy.max_result_bytes, secrets: context.secrets
        )
        stored = store.update(operation.add_bytes!(Redactor.canonical_json(bounded).bytesize, now: now))
        Result.ok(
          data: bounded, operation_id: stored.id, final_url: session.url.to_s,
          captured_at: now, locator: locator, digest: Redactor.digest(bounded), truncated: truncated
        )
      end

      def failure_result(error, attempt)
        status = status_for(error)
        recorded =
          if status == :error
            attempt.operation
          else
            transition(attempt.operation, status, error_code: error.code)
          end
        attempt.operation = recorded
        Result.failure(
          status, error_code: error.code, message: error.message,
          operation_id: recorded.id, final_url: attempt.session&.url.to_s
        )
      end

      def finish(attempt, outcome)
        closing = transition(attempt.operation, :closing)
        closed =
          begin
            backend.end_session(attempt.session, operation: closing, now: now)
          rescue Error
            false
          end

        if closed
          transition(closing, :closed)
          outcome
        else
          transition(closing, :cleanup_pending, error_code: CleanupPending.code)
          Result.failure(
            :cleanup_pending, error_code: CleanupPending.code,
            message: "browser session cleanup could not be confirmed",
            operation_id: closing.id, final_url: attempt.session&.url.to_s,
            data: outcome.ok? ? outcome.data : nil
          )
        end
      end

      # Navigates the freshly started session to the requested URL and re-checks the
      # final destination against policy. A browser-initiated redirect may only land
      # inside the approved destinations.
      def navigate(attempt)
        session = backend.navigate(attempt.session, url: attempt.uri.to_s,
                                   operation: attempt.operation, now: now)
        ensure_within_policy!(session, attempt.uri)
        session
      end

      def ensure_within_policy!(session, uri)
        final = session.url.to_s
        return if final.empty? || final == uri.to_s

        policy.authorize_destination!(final, actor_id: context.actor_id)
      rescue NotAuthorized, InvalidInput => e
        raise NotAuthorized, "the browser left the approved destinations: #{e.message}"
      end

      def ensure_no_redirect!(attempt)
        return if attempt.session.url.to_s == attempt.uri.to_s

        raise ApprovalStale, "the page changed to a different URL; the approval no longer applies"
      end

      def consume_approval!(approval_id, attempt:, action:, page_revision:)
        context.approval_store.consume_once(
          approval_id,
          actor_id: context.actor_id, run_id: context.run_id, url: attempt.uri.to_s,
          action_digest: Approval.action_digest(action), page_revision: page_revision,
          operation_id: attempt.operation.id, session_id: attempt.session.id, now: now
        )
      end

      def require_approval_store!
        return unless context.approval_store.nil?

        raise ApprovalRequired, "Act requires a configured approval store"
      end

      def transition(operation, target, session_id: :keep, error_code: nil)
        updated = operation.advance(target, now: now, session_id: session_id,
                                    error_code: error_code.nil? ? :keep : error_code)
        store.update(updated)
      rescue InvalidInput => e
        raise unless e.message.include?("illegal operation transition")

        context.logger&.warn { "browser operation transition skipped: #{e.message}" }
        operation
      end

      def status_for(error)
        case error
        when SessionUnknown then :unknown
        when CleanupPending then :cleanup_pending
        else :error
        end
      end

      def current_url(attempt)
        attempt.session.url.to_s
      end

      def optional_positive_integer!(value, name)
        return nil if value.nil?
        raise InvalidInput, "#{name} must be a positive Integer" unless value.is_a?(Integer) && value.positive?

        value
      end

      def backend = context.backend
      def policy = context.policy
      def store = context.operation_store
      def capabilities = context.capabilities
      def now = context.now
    end
  end
end
