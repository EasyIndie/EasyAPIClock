import Foundation
import GudengCore

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
