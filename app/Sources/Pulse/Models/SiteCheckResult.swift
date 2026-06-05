import Foundation

struct SiteCheckResult: Equatable {
    var status: SiteStatus
    var methodUsed: HTTPMethod
    var metadataLabel: String?
    var metadataValue: String?
}
