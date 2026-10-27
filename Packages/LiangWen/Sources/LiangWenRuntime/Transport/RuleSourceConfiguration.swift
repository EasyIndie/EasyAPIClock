import Foundation

/// Reads the optional rule source from Info.plist or an environment override.
///
/// HTTPS is required except for local development on localhost. The placeholder
/// value `OWNER` is treated as "not configured" so a fork cannot fetch silently.
public struct RuleSourceConfiguration: Sendable {
    public static let infoPlistKey = "LiangWenRuleSourceBaseURL"
    public static let environmentKey = "LIANGWEN_RULE_SOURCE"

    public let baseURL: URL?
    public let rawValue: String?

    public init(baseURL: URL?, rawValue: String? = nil) {
        self.baseURL = baseURL
        self.rawValue = rawValue
    }

    public static func resolve(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RuleSourceConfiguration {
        let raw = (environment[environmentKey] ?? infoDictionary?[infoPlistKey] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !raw.contains("OWNER") else {
            return RuleSourceConfiguration(baseURL: nil, rawValue: raw)
        }
        guard let url = URL(string: raw),
            let scheme = url.scheme?.lowercased(),
            let host = url.host
        else {
            return RuleSourceConfiguration(baseURL: nil, rawValue: raw)
        }
        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || (scheme == "http" && isLocal) else {
            return RuleSourceConfiguration(baseURL: nil, rawValue: raw)
        }
        return RuleSourceConfiguration(baseURL: url, rawValue: raw)
    }
}
