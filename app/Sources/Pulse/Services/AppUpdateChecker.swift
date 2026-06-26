import Foundation

struct AppUpdateChecker {
    struct GitHubRelease: Decodable, Equatable {
        let tagName: String
        let htmlURL: URL?

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    enum Outcome: Equatable {
        case updateAvailable(currentVersion: String, latestVersion: String, releaseURL: URL?)
        case upToDate(version: String)
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/inspectr-hq/pulse-app/releases/latest")!
    static let fallbackCurrentVersion = "0.5.5"

    var transport: HTTPTransport = URLSession.shared

    func checkForUpdates(currentVersion: String = Self.currentAppVersion()) async throws -> Outcome {
        let release = try await latestRelease()
        let latestVersion = Self.normalizedVersion(release.tagName)

        if Self.compareVersions(currentVersion, latestVersion) == .orderedAscending {
            return .updateAvailable(
                currentVersion: Self.normalizedVersion(currentVersion),
                latestVersion: latestVersion,
                releaseURL: release.htmlURL
            )
        }

        return .upToDate(version: Self.normalizedVersion(currentVersion))
    }

    func latestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    static func currentAppVersion(bundle: Bundle = .main) -> String {
        if let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !shortVersion.isEmpty {
            return shortVersion
        }
        if let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !buildVersion.isEmpty {
            return buildVersion
        }
        return fallbackCurrentVersion
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftComponents = numericVersionComponents(lhs)
        let rightComponents = numericVersionComponents(rhs)
        let componentCount = max(leftComponents.count, rightComponents.count)

        for index in 0..<componentCount {
            let left = index < leftComponents.count ? leftComponents[index] : 0
            let right = index < rightComponents.count ? rightComponents[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }

        return .orderedSame
    }

    static func normalizedVersion(_ version: String) -> String {
        let trimmed = version
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let withoutPrefix: Substring
        if trimmed.lowercased().hasPrefix("v") {
            withoutPrefix = trimmed.dropFirst()
        } else {
            withoutPrefix = Substring(trimmed)
        }

        return withoutPrefix
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? version
    }

    private static func numericVersionComponents(_ version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".")
            .map { component in
                let digits = component.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}
