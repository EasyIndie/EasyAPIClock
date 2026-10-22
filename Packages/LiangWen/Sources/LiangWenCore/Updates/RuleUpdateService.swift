import Foundation

public enum RuleUpdateError: Error, Sendable, Equatable, LocalizedError {
    case missingManifest
    case badHTTPStatus(Int)
    case unsafeFileName(String)
    case unsupportedSource(String)
    case currentBundleUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingManifest:
            "更新源缺少 manifest.json。"
        case .badHTTPStatus(let status):
            "规则服务器返回 HTTP \(status)。"
        case .unsafeFileName(let name):
            "规则文件名不安全：\(name)"
        case .unsupportedSource(let value):
            "规则更新源无效或不是 HTTPS：\(value)"
        case .currentBundleUnavailable:
            "无法读取当前规则版本。"
        }
    }
}

public protocol RuleDataFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionRuleDataFetcher: RuleDataFetching {
    public init() {}

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RuleUpdateError.badHTTPStatus(http.statusCode)
        }
        return data
    }
}

/// Fetches and validates a complete rule bundle. It never executes downloaded code.
public struct RemoteRuleUpdater: Sendable {
    public let baseURL: URL
    private let fetcher: any RuleDataFetching

    public init(baseURL: URL, fetcher: any RuleDataFetching = URLSessionRuleDataFetcher()) {
        self.baseURL = baseURL
        self.fetcher = fetcher
    }

    /// Returns a verified bundle only when the source is newer than `current`.
    public func checkForUpdate(current: RuleSet) async throws -> VerifiedRuleBundle? {
        let manifestURL = baseURL.appendingPathComponent("manifest.json")
        let manifestData = try await fetcher.data(from: manifestURL)
        let manifest: RuleBundleManifest
        do {
            manifest = try RuleJSON.makeDecoder().decode(RuleBundleManifest.self, from: manifestData)
        } catch {
            throw RuleValidationError(["manifest.json 解析失败：\(error.localizedDescription)"])
        }

        guard manifest.publishedAt > current.publishedAt else {
            return nil
        }

        var files: [String: Data] = [:]
        for name in manifest.files.all {
            guard RuleBundleLoader.isSafeFileName(name) else {
                throw RuleUpdateError.unsafeFileName(name)
            }
            files[name] = try await fetcher.data(from: baseURL.appendingPathComponent(name))
        }
        return try RuleBundleLoader.load(manifestData: manifestData, files: files)
    }
}

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
