import Foundation
import XCTest
@testable import Pulse

final class WebhookEngineTests: XCTestCase {
    func testDefaultPayloadTemplateUsesSnakeCaseKeys() {
        let config = WebhookConfig()

        XCTAssertTrue(config.payloadTemplate.contains("\"status_code\""))
        XCTAssertTrue(config.payloadTemplate.contains("\"response_ms\""))
    }

    func testPayloadTemplateReplacesAllPlaceholdersWithoutCorruptingStatusCode() async throws {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let event = WebhookTransitionEvent(
            message: "Inspectr is down",
            monitorName: "Inspectr",
            monitorURL: "https://inspectr.dev",
            status: "down",
            trigger: "manual",
            statusCode: 503,
            responseMs: 12,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "https://example.com/hook",
            method: .post,
            payloadTemplate: """
            {
              "message": "$MESSAGE",
              "monitor": "$MONITOR",
              "status": "$STATUS",
              "status_code": "$STATUS_CODE",
              "response_ms": "$RESPONSE_MS",
              "trigger": "$TRIGGER",
              "timestamp": "$TIMESTAMP",
              "url": "$URL"
            }
            """
        )

        engine.sendTransition(event: event, config: config)
        await transport.waitForRequests(count: 1)

        let request = try await transport.firstRequest()
        let body = try XCTUnwrap(request.httpBody).asUTF8String()

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertTrue(body.contains("\"status\": \"down\""))
        XCTAssertTrue(body.contains("\"status_code\": \"503\""))
        XCTAssertTrue(body.contains("\"response_ms\": \"12\""))
        XCTAssertFalse(body.contains("down_CODE"))
        XCTAssertFalse(body.contains("$STATUS_CODE"))
    }

    func testPostWebhookSetsJsonContentTypeAndBody() async throws {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let event = sampleEvent()
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "https://example.com/hook",
            method: .post,
            payloadTemplate: "{ \"status\": \"$STATUS\" }"
        )

        engine.sendTransition(event: event, config: config)
        await transport.waitForRequests(count: 1)

        let request = try await transport.firstRequest()
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)
    }

    func testGetWebhookOmitsBody() async throws {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "https://example.com/hook",
            method: .get,
            payloadTemplate: "{ \"status\": \"$STATUS\" }"
        )

        engine.sendTransition(event: sampleEvent(), config: config)
        await transport.waitForRequests(count: 1)

        let request = try await transport.firstRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
    }

    func testHeadWebhookOmitsBody() async throws {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "https://example.com/hook",
            method: .head,
            payloadTemplate: "{ \"status\": \"$STATUS\" }"
        )

        engine.sendTransition(event: sampleEvent(), config: config)
        await transport.waitForRequests(count: 1)

        let request = try await transport.firstRequest()
        XCTAssertEqual(request.httpMethod, "HEAD")
        XCTAssertNil(request.httpBody)
    }

    func testEmptyUrlSkipsDispatch() async {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "   ",
            method: .post,
            payloadTemplate: "{ \"status\": \"$STATUS\" }"
        )

        engine.sendTransition(event: sampleEvent(), config: config)
        await transport.waitForRequests(count: 0, timeout: 150_000_000)

        let emptyCount = await transport.requestCount()
        XCTAssertEqual(emptyCount, 0)
    }

    func testInvalidUrlSkipsDispatch() async {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "not a url",
            method: .post,
            payloadTemplate: "{ \"status\": \"$STATUS\" }"
        )

        engine.sendTransition(event: sampleEvent(), config: config)
        await transport.waitForRequests(count: 0, timeout: 150_000_000)

        let invalidCount = await transport.requestCount()
        XCTAssertEqual(invalidCount, 0)
    }

    func testDisabledWebhookSkipsDispatch() async {
        let transport = RecordingTransport(responses: [.success])
        let engine = WebhookEngine(transport: transport)
        let config = WebhookConfig(
            name: "Test",
            isEnabled: false,
            url: "https://example.com/hook",
            method: .post,
            payloadTemplate: "{ \"status\": \"$STATUS\" }"
        )

        engine.sendTransition(event: sampleEvent(), config: config)
        await transport.waitForRequests(count: 0, timeout: 150_000_000)

        let disabledCount = await transport.requestCount()
        XCTAssertEqual(disabledCount, 0)
    }

    func testWebhookRetriesWithExponentialBackoff() async {
        let transport = RecordingTransport(responses: [.failure, .failure, .success])
        let engine = WebhookEngine(transport: transport)
        let config = WebhookConfig(
            name: "Test",
            isEnabled: true,
            url: "https://example.com/hook",
            method: .post,
            payloadTemplate: "{ \"status\": \"$STATUS\" }",
            maxRetries: 2,
            initialBackoffSeconds: 0.1
        )

        let startedAt = Date()
        engine.sendTransition(event: sampleEvent(), config: config)
        await transport.waitForRequests(count: 3)
        let finishedAt = Date()

        let requests = await transport.requestCount()
        let timestamps = await transport.requestTimes()
        XCTAssertEqual(requests, 3)
        XCTAssertGreaterThanOrEqual(finishedAt.timeIntervalSince(startedAt), 0.25)
        XCTAssertGreaterThan(timestamps[1].timeIntervalSince(timestamps[0]), 0.08)
        XCTAssertGreaterThan(timestamps[2].timeIntervalSince(timestamps[1]), 0.15)
    }

    private func sampleEvent() -> WebhookTransitionEvent {
        WebhookTransitionEvent(
            message: "Inspectr is down",
            monitorName: "Inspectr",
            monitorURL: "https://inspectr.dev",
            status: "down",
            trigger: "automatic",
            statusCode: 500,
            responseMs: 42,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

actor RecordingTransport: HTTPTransport {
    enum Stub {
        case success
        case failure
    }

    private var queue: [Stub]
    private var requests: [URLRequest] = []
    private var requestTimestamps: [Date] = []

    init(responses: [Stub]) {
        self.queue = responses
    }

    func waitForRequests(count: Int, timeout: UInt64 = 3_000_000_000) async {
        if count == 0 {
            try? await Task.sleep(nanoseconds: timeout)
            return
        }

        let deadline = DispatchTime.now().uptimeNanoseconds + timeout
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let currentCount = requests.count
            if currentCount >= count { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func requestCount() -> Int {
        requests.count
    }

    func requestTimes() -> [Date] {
        requestTimestamps
    }

    func firstRequest() throws -> URLRequest {
        try XCTUnwrap(requests.first)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        record(request: request)

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let next = nextStub()
        switch next {
        case .success:
            return (Data(), response)
        case .failure:
            throw URLError(.timedOut)
        }
    }

    private func record(request: URLRequest) {
        requests.append(request)
        requestTimestamps.append(Date())
    }

    private func nextStub() -> Stub {
        queue.isEmpty ? .success : queue.removeFirst()
    }
}

private extension Data {
    func asUTF8String() throws -> String {
        try XCTUnwrap(String(data: self, encoding: .utf8))
    }
}
