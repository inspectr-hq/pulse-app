import Foundation

protocol SiteChecking {
    func check(_ monitor: SiteMonitor) async -> SiteCheckResult
}

final class SiteChecker: SiteChecking {
    private let transport: HTTPTransport

    init(transport: HTTPTransport = URLSession.shared) {
        self.transport = transport
    }

    static func isUpStatusCode(_ code: Int) -> Bool {
        (200...399).contains(code)
    }

    func check(_ monitor: SiteMonitor) async -> SiteCheckResult {
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

    private func performRequest(monitor: SiteMonitor, method: HTTPMethod, start: Date) async -> SiteCheckResult {
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
            let metadata = extractMetadata(from: monitor, data: data, response: http)
            if Self.isUpStatusCode(code) {
                if !monitor.keyword.isEmpty {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    if !body.contains(monitor.keyword) {
                        return .init(status: .down(reason: "Keyword missing", statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method, metadataLabel: metadata?.label, metadataValue: metadata?.value)
                    }
                }
                if elapsed > monitor.thresholdMs {
                    return .init(status: .down(reason: "Slow response", statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method, metadataLabel: metadata?.label, metadataValue: metadata?.value)
                }
                return .init(status: .up(statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method, metadataLabel: metadata?.label, metadataValue: metadata?.value)
            }

            return .init(status: .down(reason: "HTTP \(code)", statusCode: code, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method, metadataLabel: metadata?.label, metadataValue: metadata?.value)
        } catch {
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            return .init(status: .down(reason: error.localizedDescription, statusCode: nil, responseTimeMs: elapsed, checkedAt: Date()), methodUsed: method)
        }
    }

    private func extractMetadata(
        from monitor: SiteMonitor,
        data: Data,
        response: HTTPURLResponse
    ) -> (label: String, value: String)? {
        guard let extraction = monitor.responseMetadataExtraction,
              extraction.isEnabled else {
            return nil
        }

        let trimmedLabel = extraction.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return nil }

        let value: String?
        switch extraction.mode {
        case .jsonPath:
            value = extractJSONValue(pattern: extraction.pattern, data: data)
        case .header:
            value = extractHeaderValue(pattern: extraction.pattern, response: response)
        case .regex:
            value = extractRegexValue(pattern: extraction.pattern, data: data)
        }

        guard let value, !value.isEmpty else { return nil }
        return (label: trimmedLabel, value: value)
    }

    private func extractJSONValue(pattern: String, data: Data) -> String? {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("$.") else { return nil }

        let path = trimmed.dropFirst(2).split(separator: ".").map(String.init)
        guard !path.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data),
              let value = resolveJSON(path: path, in: json) else {
            return nil
        }

        return stringifyJSONScalar(value)
    }

    private func resolveJSON(path: [String], in value: Any) -> Any? {
        var current: Any = value
        for key in path {
            guard let object = current as? [String: Any],
                  let next = object[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    private func stringifyJSONScalar(_ value: Any) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func extractHeaderValue(pattern: String, response: HTTPURLResponse) -> String? {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for (key, value) in response.allHeaderFields {
            guard let keyString = key as? String,
                  keyString.caseInsensitiveCompare(trimmed) == .orderedSame else {
                continue
            }
            return value as? String ?? String(describing: value)
        }

        return nil
    }

    private func extractRegexValue(pattern: String, data: Data) -> String? {
        guard let body = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range) else {
            return nil
        }

        let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
        guard captureRange.location != NSNotFound,
              let swiftRange = Range(captureRange, in: body) else {
            return nil
        }

        return String(body[swiftRange])
    }
}
