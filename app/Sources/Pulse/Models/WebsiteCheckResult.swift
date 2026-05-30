import Foundation

struct WebsiteCheckResult: Equatable {
    var status: WebsiteStatus
    var methodUsed: HTTPMethod
}
