import Foundation

public enum UpdateReport: Equatable {
    case upToDate(current: String)
    case available(current: String, latest: String, page: URL)
    case ahead(current: String, latest: String)
    case failed(String)

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    public var text: String {
        switch self {
        case .upToDate(let current):
            return "Corkboard \(current) is up to date."
        case .ahead(let current, let latest):
            return "Corkboard \(current) is newer than the latest release (\(latest))."
        case .available(let current, let latest, let page):
            return "Corkboard \(latest) is available (you have \(current)).\n\(page.absoluteString)"
        case .failed(let message):
            return message
        }
    }
}

public enum UpdateChecker {
    public static let repository = "indri-za/corkboard"

    public static func request(current: String = CorkboardVersion.current) -> URLRequest {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("corkboard/\(current)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    public static func report(
        current: String, data: Data?, response: URLResponse?, error: Error?
    ) -> UpdateReport {
        if let error {
            return .failed("Couldn't check for updates. \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status), let data else {
            return .failed("Couldn't check for updates (HTTP \(status)).")
        }
        return report(current: current, body: data)
    }

    public static func report(current: String, body: Data) -> UpdateReport {
        guard let currentVersion = AppVersion(tag: current) else {
            return .failed("This build's version couldn't be read.")
        }
        guard let release = decode(body) else {
            return .failed("Couldn't read the latest release.")
        }
        guard let latest = AppVersion(tag: release.tag) else {
            return .failed("Couldn't read the latest release tag (\(release.tag)).")
        }
        if latest > currentVersion {
            return .available(
                current: currentVersion.description, latest: latest.description, page: release.page)
        }
        if latest < currentVersion {
            return .ahead(current: currentVersion.description, latest: latest.description)
        }
        return .upToDate(current: currentVersion.description)
    }

    private struct GitHubRelease: Decodable {
        var tagName: String
        var htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private static func decode(_ body: Data) -> (tag: String, page: URL)? {
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: body) else {
            return nil
        }
        return (release.tagName, release.htmlURL)
    }
}
