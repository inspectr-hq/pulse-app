import Foundation

protocol WebsiteChecking {
    func check(_ monitor: WebsiteMonitor) async -> WebsiteCheckResult
}

final class WebsiteChecker: WebsiteChecking {
    private let transport: HTTPTransport

    init(transport: HTTPTransport = URLSession.shared) {
        self.transport = transport
    }

    static func isUpStatusCode(_ code: Int) -> Bool {
        (200...399).contains(code)
    }

    func check(_ monitor: WebsiteMonitor) async -> WebsiteCheckResult {
        let start = Date()
        let headFirst = monitor.method == .head

        if headFirst {
            let first = await performRequest(monitor: monitor, method: .head, start: start)
            if case .down(_, let code, _, _) = first.status, code == 405 || code == 501 {
                return await performRequest(monitor: monitor, method: .get, start: start)
            }
            return first
        }

        return await performRequest(monitor: monitor, method: monitor.method, start: start)
    }

    private func performRequest(monitor: WebsiteMonitor, method: HTTPMethod, start: Date) async -> WebsiteCheckResult {
        var req = URLRequest(url: monitor.url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 10
        monitor.headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.name) }
        if method != .head && !monitor.body.isEmpty {
            req.httpBody = monitor.body.data(using: .utf8)
        }

        do {
            let (data, response) = try await transport.data(for: req)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else {
                return .init(status: .down(reason: "Invalid response", statusCode: nil, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
            }

            let code = http.statusCode
            if Self.isUpStatusCode(code) {
                if !monitor.keyword.isEmpty {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    if !body.contains(monitor.keyword) {
                        return .init(status: .down(reason: "Keyword missing", statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
                    }
                }
                if elapsed > monitor.thresholdMs {
                    return .init(status: .down(reason: "Slow response", statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
                }
                return .init(status: .up(statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
            }

            return .init(status: .down(reason: "HTTP \(code)", statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
        } catch {
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            return .init(status: .down(reason: error.localizedDescription, statusCode: nil, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
        }
    }
}
