import Foundation
import Testing
import GudengRuntime

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
                    "https://raw.githubusercontent.com/OWNER/gudeng-clock/main/Rules"
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

    @Test("改名前的配置键仍可读取，新键优先")
    func legacyConfigurationKeys() {
        let legacyPlist = RuleSourceConfiguration.resolve(
            infoDictionary: [
                RuleSourceConfiguration.legacyInfoPlistKey: "https://legacy.example.com/rules"
            ],
            environment: [:]
        )
        #expect(legacyPlist.baseURL == URL(string: "https://legacy.example.com/rules"))

        let legacyEnvironment = RuleSourceConfiguration.resolve(
            infoDictionary: [:],
            environment: [
                RuleSourceConfiguration.legacyEnvironmentKey: "https://legacy-env.example.com/rules"
            ]
        )
        #expect(legacyEnvironment.baseURL == URL(string: "https://legacy-env.example.com/rules"))

        let prefersCurrent = RuleSourceConfiguration.resolve(
            infoDictionary: [
                RuleSourceConfiguration.legacyInfoPlistKey: "https://legacy.example.com/rules",
                RuleSourceConfiguration.infoPlistKey: "https://current.example.com/rules",
            ],
            environment: [:]
        )
        #expect(prefersCurrent.baseURL == URL(string: "https://current.example.com/rules"))
    }
}
