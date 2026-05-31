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
    func sendTransition(event: WebhookTransitionEvent, settings: AppSettings)
}

final class WebhookEngine: WebhookDispatching {
    private let transport: HTTPTransport

    init(transport: HTTPTransport = URLSession.shared) {
        self.transport = transport
    }

    func sendTransition(event: WebhookTransitionEvent, settings: AppSettings) {
        guard settings.webhookEnabled,
              let url = URL(string: settings.webhookURL),
              !settings.webhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let payload = buildPayload(template: settings.webhookPayloadTemplate, event: event)
        let attempts = max(1, settings.webhookMaxRetries + 1)
        let backoff = max(0.1, settings.webhookInitialBackoffSeconds)

        Task.detached(priority: .utility) { [transport] in
            for attempt in 0..<attempts {
                var request = URLRequest(url: url)
                request.httpMethod = settings.webhookMethod.rawValue
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 10
                if settings.webhookMethod != .head {
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
        output = output.replacingOccurrences(of: "$STATUS", with: event.status)
        output = output.replacingOccurrences(of: "$TRIGGER", with: event.trigger)
        output = output.replacingOccurrences(of: "$STATUS_CODE", with: event.statusCode.map(String.init) ?? "")
        output = output.replacingOccurrences(of: "$RESPONSE_MS", with: event.responseMs.map(String.init) ?? "")
        output = output.replacingOccurrences(of: "$TIMESTAMP", with: ISO8601DateFormatter().string(from: event.timestamp))
        return output
    }
}
