# frozen_string_literal: true

# Internal loopback canaries mounted only by the opted-in workbench test instance.
class BrowserWorkbench
  class NetworkProbe # :nodoc:
    KINDS = %w[fetch frame image popup script websocket worker redirect].freeze

    def initialize
      @cases = {}
      @mutex = Mutex.new
    end

    def new_case
      @mutex.synchronize do
        id = SecureRandom.hex(16)
        @cases[id] = {}
        @cases.shift while @cases.size > 16
        id
      end
    end

    def hits(id)
      @mutex.synchronize { @cases.fetch(id).dup }
    end

    def call(request)
      return response(405, "Method not allowed") unless request.get?

      _, _, id, action, kind = request.path.split("/")
      return response(404, "Unknown case") unless @mutex.synchronize { @cases.key?(id) }
      if action == "hit" && kind == "websocket"
        upgrade = request.get_header("HTTP_UPGRADE").to_s.downcase == "websocket"
        connection = request.get_header("HTTP_CONNECTION").to_s.downcase.split(",").map(&:strip)
        return response(400, "Expected WebSocket upgrade") unless upgrade && connection.include?("upgrade")
      end
      return hit(id, kind) if action == "hit" && KINDS.include?(kind)

      target = request.params.fetch("target", "cross")
      return response(400, "Unknown target") unless %w[same cross].include?(target)

      # No supplied URL or host is accepted. Both origins use this loopback server.
      host = target == "same" ? "127.0.0.1" : "localhost"
      root = "http://#{host}:#{request.port}/network-probe/#{id}"
      case action
      when "page" then response(200, page(id, root, target))
      when "worker" then response(200, "fetch(#{JSON.generate("#{root}/hit/worker")}).catch(() => {});", type: "text/javascript")
      when "redirect" then response(302, "Redirecting", headers: { "location" => "#{root}/hit/redirect" })
      else response(404, "Not found")
      end
    end

    private

    def hit(id, kind)
      @mutex.synchronize do
        return response(404, "Unknown case") unless @cases.key?(id)

        @cases[id][kind] = [ @cases[id].fetch(kind, 0) + 1, 100 ].min
      end
      case kind
      when "websocket" then response(426, "WebSocket handshake received; no tunnel is opened")
      when "script" then response(200, "window.canaryScriptLoaded = true;", type: "text/javascript")
      when "image" then response(200, '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>', type: "image/svg+xml")
      else response(200, "<!doctype html><title>Canary received: #{kind}</title><p>Loopback canary received: #{kind}</p>")
      end
    end

    def response(status, body, type: "text/html; charset=utf-8", headers: {})
      [ status, { "content-type" => type, "cache-control" => "no-store",
                  "access-control-allow-origin" => "*" }.merge(headers), [ body ] ]
    end

    def page(id, root, target)
      <<~HTML
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>RubyLLM Browser · Network canaries</title>
        <style>
        * { box-sizing: border-box; } body { max-width: 800px; margin: 32px auto; padding: 16px; font: 16px/1.6 system-ui, sans-serif; color: #172033; }
        button, a { font: inherit; } button { padding: 12px; } iframe { width: 100%; height: 80px; border: 1px solid #ccc; }
        :focus-visible { outline: 3px solid #cf6800; outline-offset: 3px; } code { overflow-wrap: anywhere; }
        </style></head><body>
        <h1>Offline network canaries</h1><p>Fixture calibration only. This browser is not isolated or qualified.</p>
        <p>Target: <code>#{root}</code></p>
        <button id="send" type="button">Send probes</button>
        <p id="sent" aria-live="polite">No probes sent</p>
        <p><a href="/network-probe/#{id}/redirect?target=#{target}">Follow redirect</a></p>
        <script>
        const root = #{JSON.generate(root)};
        document.querySelector('#send').addEventListener('click', () => {
          document.querySelector('#send').disabled = true;
          window.open(root + '/hit/popup', '_blank');
          fetch(root + '/hit/fetch').catch(() => {});
          const image = new Image(); image.id = 'canary-image'; image.src = root + '/hit/image'; document.body.append(image);
          const script = document.createElement('script'); script.src = root + '/hit/script'; document.body.append(script);
          const frame = document.createElement('iframe'); frame.title = 'Loopback canary'; frame.src = root + '/hit/frame'; document.body.append(frame);
          window.canaryWorker = new Worker('/network-probe/#{id}/worker?target=#{target}');
          window.canarySocket = new WebSocket(root.replace('http:', 'ws:') + '/hit/websocket');
          document.querySelector('#sent').textContent = 'All seven request paths attempted';
        });
        </script></body></html>
      HTML
    end
  end
end
