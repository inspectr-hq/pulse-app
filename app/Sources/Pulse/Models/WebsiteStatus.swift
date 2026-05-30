import Foundation

enum WebsiteStatus: Equatable {
    case unknown
    case checking
    case up(statusCode: Int, responseTimeMs: Int, checkedAt: Date)
    case down(reason: String, statusCode: Int?, responseTimeMs: Int?, checkedAt: Date)
    case paused

    var checkedAt: Date? {
        switch self {
        case .up(_, _, let checkedAt), .down(_, _, _, let checkedAt):
            return checkedAt
        case .unknown, .checking, .paused:
            return nil
        }
    }
}

enum OverallStatus: Equatable {
    case neutral
    case unknown
    case checking
    case up
    case down
}
