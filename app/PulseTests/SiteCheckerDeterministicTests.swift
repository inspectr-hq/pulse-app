import XCTest
@testable import Pulse

final class SiteCheckerDeterministicTests: XCTestCase {
    func testHeadSuccessReturnsUpUsingHead() async {
        let transport = MockTransport(responses: [.success(statusCode: 200, data: Data())])
        let checker = SiteChecker(transport: transport)
        let monitor = SiteMonitor(url: URL(string: "https://example.com")!, method: .head)

        let result = await checker.check(monitor)

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.httpMethod, "HEAD")
        XCTAssertEqual(result.methodUsed, .head)
        if case .up(let code, _, _) = result.status {
            XCTAssertEqual(code, 200)
        } else {
            XCTFail("Expected up status")
        }
    }

    func testHead405FallsBackToGet() async {
        let transport = MockTransport(responses: [
            .success(statusCode: 405, data: Data()),
            .success(statusCode: 200, data: Data())
        ])
        let checker = SiteChecker(transport: transport)
        let monitor = SiteMonitor(url: URL(string: "https://example.com")!, method: .head)

        let result = await checker.check(monitor)

        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[0].httpMethod, "HEAD")
        XCTAssertEqual(transport.requests[1].httpMethod, "GET")
        XCTAssertEqual(result.methodUsed, .get)
    }

    func testNetworkErrorReturnsDown() async {
        let transport = MockTransport(responses: [.failure(URLError(.timedOut))])
        let checker = SiteChecker(transport: transport)
        let monitor = SiteMonitor(url: URL(string: "https://example.com")!, method: .get)

        let result = await checker.check(monitor)

        if case .down(let reason, _, _, _) = result.status {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Expected down status")
        }
    }

    func testKeywordMissingReturnsDown() async {
        let body = Data("hello world".utf8)
        let transport = MockTransport(responses: [.success(statusCode: 200, data: body)])
        let checker = SiteChecker(transport: transport)
        var monitor = SiteMonitor(url: URL(string: "https://example.com")!, method: .get)
        monitor.keyword = "needle"

        let result = await checker.check(monitor)

        if case .down(let reason, let code, _, _) = result.status {
            XCTAssertEqual(reason, "Keyword missing")
            XCTAssertEqual(code, 200)
        } else {
            XCTFail("Expected down status")
        }
    }

    func testThresholdExceededReturnsDown() async {
        let body = Data("ok".utf8)
        let transport = MockTransport(responses: [.success(statusCode: 200, data: body)])
        let checker = SiteChecker(transport: transport)
        var monitor = SiteMonitor(url: URL(string: "https://example.com")!, method: .get)
        monitor.thresholdMs = -1

        let result = await checker.check(monitor)

        if case .down(let reason, let code, _, _) = result.status {
            XCTAssertEqual(reason, "Slow response")
            XCTAssertEqual(code, 200)
        } else {
            XCTFail("Expected down status")
        }
    }
}

private final class MockTransport: HTTPTransport {
    enum Stub {
        case success(statusCode: Int, data: Data)
        case failure(Error)
    }

    private var queue: [Stub]
    private(set) var requests: [URLRequest] = []

    init(responses: [Stub]) {
        self.queue = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !queue.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let next = queue.removeFirst()
        switch next {
        case .success(let statusCode, let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}
