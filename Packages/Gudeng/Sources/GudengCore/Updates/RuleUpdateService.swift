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

/// Fetches and validates a complete rule bundle. It never executes downloaded code.
public struct RemoteRuleUpdater: Sendable {
    public let baseURL: URL
    private let fetcher: any RuleDataFetching

    public init(baseURL: URL, fetcher: any RuleDataFetching) {
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
