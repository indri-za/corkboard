import Foundation

/// Published version, without a leading `v`. Keep it aligned with the release tag.
public enum CorkboardVersion {
    public static let current = "0.2.0"
}

/// A `major.minor.patch` version. A leading `v` is accepted so release tags compare cleanly.
public struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(tag: String) {
        var raw = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.first == "v" || raw.first == "V" {
            raw.removeFirst()
        }
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        major = numbers[0]
        minor = numbers.count > 1 ? numbers[1] : 0
        patch = numbers.count > 2 ? numbers[2] : 0
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
