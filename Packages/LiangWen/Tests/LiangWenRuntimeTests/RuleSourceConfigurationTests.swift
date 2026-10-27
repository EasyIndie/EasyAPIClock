import Foundation
import Testing
import LiangWenRuntime

@Suite("规则源平台配置")
struct RuleSourceConfigurationTests {
    @Test("更新源配置要求 HTTPS，OWNER 占位符视为未配置")
    func sourceConfiguration() throws {
        let https = RuleSourceConfiguration.resolve(
            infoDictionary: [RuleSourceConfiguration.infoPlistKey: "https://example.com/rules"],
            environment: [:]
        )
        #expect(https.baseURL == URL(string: "https://example.com/rules"))

        let placeholder = RuleSourceConfiguration.resolve(
            infoDictionary: [
                RuleSourceConfiguration.infoPlistKey:
                    "https://raw.githubusercontent.com/OWNER/liangwen-clock/main/Rules"
            ],
            environment: [:]
        )
        #expect(placeholder.baseURL == nil)

        let insecure = RuleSourceConfiguration.resolve(
            infoDictionary: [RuleSourceConfiguration.infoPlistKey: "http://example.com/rules"],
            environment: [:]
        )
        #expect(insecure.baseURL == nil)

        let local = RuleSourceConfiguration.resolve(
            infoDictionary: [:],
            environment: [RuleSourceConfiguration.environmentKey: "http://localhost:8080/Rules"]
        )
        #expect(local.baseURL == URL(string: "http://localhost:8080/Rules"))
    }
}
