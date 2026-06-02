import Foundation

struct WebhookTransitionEvent {
    let message: String
    let monitorName: String
    let monitorURL: String
    let status: String
    let trigger: String
    let statusCode: Int?
    let responseMs: Int?
    let timestamp: Date
}

protocol WebhookDispatching {
    func sendTransition(event: WebhookTransitionEvent, config: WebhookConfig)
}

final class WebhookEngine: WebhookDispatching {
    private let transport: HTTPTransport

    init(transport: HTTPTransport = URLSession.shared) {
        self.transport = transport
    }

    func sendTransition(event: WebhookTransitionEvent, config: WebhookConfig) {
        guard config.isEnabled,
              let url = validatedWebhookURL(config.url) else { return }

        let payload = buildPayload(template: config.payloadTemplate, event: event)
        let attempts = max(1, config.maxRetries + 1)
        let backoff = max(0.1, config.initialBackoffSeconds)

        Task.detached(priority: .utility) { [transport] in
            for attempt in 0..<attempts {
                var request = URLRequest(url: url)
                request.httpMethod = config.method.rawValue
                request.timeoutInterval = 10
                if config.method == .post {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = payload.data(using: .utf8)
                }

                do {
                    _ = try await transport.data(for: request)
                    return
                } catch {
                    if attempt == attempts - 1 { return }
                    let delay = backoff * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }

    private func buildPayload(template: String, event: WebhookTransitionEvent) -> String {
        var output = template
        output = output.replacingOccurrences(of: "$MESSAGE", with: event.message)
        output = output.replacingOccurrences(of: "$MONITOR", with: event.monitorName)
        output = output.replacingOccurrences(of: "$URL", with: event.monitorURL)
        output = output.replacingOccurrences(of: "$TRIGGER", with: event.trigger)
        output = output.replacingOccurrences(of: "$STATUS_CODE", with: event.statusCode.map(String.init) ?? "")
        output = output.replacingOccurrences(of: "$RESPONSE_MS", with: event.responseMs.map(String.init) ?? "")
        output = output.replacingOccurrences(of: "$STATUS", with: event.status)
        output = output.replacingOccurrences(of: "$TIMESTAMP", with: ISO8601DateFormatter().string(from: event.timestamp))
        return output
    }

    private func validatedWebhookURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return nil
        }
        return url
    }
}
