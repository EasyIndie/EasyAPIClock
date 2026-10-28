import Foundation

/// The app's user-visible version and build number.
///
/// Kept in the presentation layer so tests and previews can use explicit values
/// while the real app reads them from its bundle.
public struct AppVersion: Equatable, Sendable {
    public let shortVersion: String
    public let build: String

    public init(shortVersion: String, build: String) {
        self.shortVersion = shortVersion
        self.build = build
    }

    public static func current(bundle: Bundle = .main) -> AppVersion {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return AppVersion(
            shortVersion: version.flatMap { $0.isEmpty ? nil : $0 } ?? "—",
            build: build.flatMap { $0.isEmpty ? nil : $0 } ?? "—"
        )
    }
}
