import Foundation
import Testing
@testable import GudengCore

enum TestPaths {
    static var rulesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GudengCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Gudeng
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repository root
            .appendingPathComponent("Rules")
    }
}

@Suite("规则包加载与完整性")
struct RuleBundleTests {
    @Test("仓库内置规则包可通过校验")
    func loadsRepositoryRules() throws {
        let bundle = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        #expect(bundle.manifest.bundleVersion == "2026.10.23")
        #expect(bundle.ruleSet.pricing.models.count == 2)
        #expect(bundle.ruleSet.pricing.models.flatMap(\.tiers).count == 6)
        #expect(bundle.ruleSet.calendar.holidays.count == 7)
        #expect(bundle.ruleSet.calendar.coverage.through == Fixture.localDate("2026-12-31"))
        #expect(
            bundle.ruleSet.pricing.source.url == URL(string: "https://api-docs.deepseek.com/zh-cn/quick_start/pricing/")
        )
        #expect(bundle.ruleSet.reminderPolicy.defaultIntensity == .medium)
    }

    @Test("内置价格快照与官方页面一致")
    func pricesMatchSnapshot() throws {
        let bundle = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let flash = try #require(bundle.ruleSet.pricing.models.first { $0.id == "deepseek-flash" })
        let cacheHit = try #require(flash.tiers.first { $0.id == "inputCacheHit" })
        #expect(cacheHit.valley.value == Decimal(string: "0.02"))
        #expect(cacheHit.peak.value == Decimal(string: "0.04"))

        let pro = try #require(bundle.ruleSet.pricing.models.first { $0.id == "deepseek-v4-pro" })
        let output = try #require(pro.tiers.first { $0.id == "output" })
        #expect(output.valley.value == Decimal(string: "13.5"))
        #expect(output.peak.value == Decimal(string: "27"))
    }

    @Test("校验和错误时拒绝整个规则包")
    func rejectsTamperedFile() throws {
        let bundle = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        var files = bundle.files
        var pricing = try #require(files[bundle.manifest.files.pricing])
        pricing.append(0x20)
        files[bundle.manifest.files.pricing] = pricing
        let manifestData = try RuleJSON.makeEncoder().encode(bundle.manifest)
        #expect(throws: RuleValidationError.self) {
            _ = try RuleBundleLoader.load(manifestData: manifestData, files: files)
        }
    }

    @Test("缺少文件或包含未声明文件时拒绝")
    func rejectsIncompleteBundles() throws {
        let bundle = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let manifestData = try RuleJSON.makeEncoder().encode(bundle.manifest)

        var missing = bundle.files
        missing.removeValue(forKey: bundle.manifest.files.calendar)
        #expect(throws: RuleValidationError.self) {
            _ = try RuleBundleLoader.load(manifestData: manifestData, files: missing)
        }

        var extra = bundle.files
        extra["unexpected.json"] = Data("{}".utf8)
        #expect(throws: RuleValidationError.self) {
            _ = try RuleBundleLoader.load(manifestData: manifestData, files: extra)
        }
    }

    @Test("拒绝路径穿越的文件名")
    func rejectsUnsafeFileNames() throws {
        let bundle = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let unsafeManifest = RuleBundleManifest(
            schemaVersion: 1,
            bundleVersion: "unsafe",
            publishedAt: bundle.manifest.publishedAt,
            effectiveFrom: bundle.manifest.effectiveFrom,
            files: RuleFileNames(pricing: "../pricing.json", calendar: "c.json", reminderPolicy: "p.json"),
            sha256: bundle.manifest.sha256,
            notes: nil
        )
        let data = try RuleJSON.makeEncoder().encode(unsafeManifest)
        #expect(throws: RuleValidationError.self) {
            _ = try RuleBundleLoader.load(manifestData: data, files: ["../pricing.json": Data()])
        }
    }

    @Test("提醒策略边界校验")
    func validatesPolicyBounds() {
        let tooEarly = Fixture.policy(advanceSeconds: [30])
        #expect(!RuleValidator.validate(policy: tooEarly).isEmpty)

        let tooLong = Fixture.policy(repeatInterval: 600, maxRepeats: 60)
        #expect(!RuleValidator.validate(policy: tooLong).isEmpty)

        #expect(RuleValidator.validate(policy: Fixture.policy()).isEmpty)
    }
}

@Suite("远程规则更新")
struct RuleUpdateTests {
    private struct FakeFetcher: RuleDataFetching {
        let payloads: [URL: Data]
        func data(from url: URL) async throws -> Data {
            guard let data = payloads[url] else { throw URLError(.fileDoesNotExist) }
            return data
        }
    }

    private func makeNewerManifest(
        base: VerifiedRuleBundle,
        fileNames: RuleFileNames? = nil,
        publishedAt: Date? = nil
    ) -> RuleBundleManifest {
        RuleBundleManifest(
            schemaVersion: 1,
            bundleVersion: "test-newer",
            publishedAt: publishedAt ?? base.manifest.publishedAt.addingTimeInterval(3600),
            effectiveFrom: base.manifest.effectiveFrom,
            files: fileNames ?? base.manifest.files,
            sha256: base.manifest.sha256,
            notes: nil
        )
    }

    private func payloads(base: VerifiedRuleBundle, manifest: RuleBundleManifest, baseURL: URL) throws -> [URL: Data] {
        var result: [URL: Data] = [
            baseURL.appendingPathComponent("manifest.json"): try RuleJSON.makeEncoder().encode(manifest)
        ]
        for name in manifest.files.all {
            if let data = base.files[name] {
                result[baseURL.appendingPathComponent(name)] = data
            }
        }
        return result
    }

    @Test("发现更新时返回完整校验后的规则包")
    func findsNewerBundle() async throws {
        let base = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let manifest = makeNewerManifest(base: base)
        let baseURL = URL(string: "https://example.com/rules")!
        let fetcher = FakeFetcher(payloads: try payloads(base: base, manifest: manifest, baseURL: baseURL))
        let updater = RemoteRuleUpdater(baseURL: baseURL, fetcher: fetcher)
        let update = try await updater.checkForUpdate(current: base.ruleSet)
        #expect(update?.manifest.bundleVersion == "test-newer")
        #expect((update?.ruleSet.pricing.models.count ?? 0) > 0)
    }

    @Test("相同或更旧的发布时间不触发更新")
    func ignoresSameOrOlderBundle() async throws {
        let base = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let manifest = makeNewerManifest(base: base, publishedAt: base.manifest.publishedAt)
        let baseURL = URL(string: "https://example.com/rules")!
        let fetcher = FakeFetcher(payloads: try payloads(base: base, manifest: manifest, baseURL: baseURL))
        let updater = RemoteRuleUpdater(baseURL: baseURL, fetcher: fetcher)
        let update = try await updater.checkForUpdate(current: base.ruleSet)
        #expect(update == nil)
    }

    @Test("下载内容被篡改时拒绝")
    func rejectsCorruptedDownload() async throws {
        let base = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let manifest = makeNewerManifest(base: base)
        let baseURL = URL(string: "https://example.com/rules")!
        var payloads = try payloads(base: base, manifest: manifest, baseURL: baseURL)
        payloads[baseURL.appendingPathComponent(manifest.files.pricing)] = Data("{}".utf8)
        let updater = RemoteRuleUpdater(baseURL: baseURL, fetcher: FakeFetcher(payloads: payloads))
        await #expect(throws: RuleValidationError.self) {
            _ = try await updater.checkForUpdate(current: base.ruleSet)
        }
    }

    @Test("下载失败时向上抛出，调用方保留旧规则")
    func propagatesDownloadFailure() async throws {
        let base = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let baseURL = URL(string: "https://example.com/rules")!
        let updater = RemoteRuleUpdater(baseURL: baseURL, fetcher: FakeFetcher(payloads: [:]))
        await #expect(throws: URLError.self) {
            _ = try await updater.checkForUpdate(current: base.ruleSet)
        }
    }

    @Test("拒绝未安全声明的远程文件名")
    func rejectsUnsafeRemoteFile() async throws {
        let base = try RuleBundleLoader.load(from: TestPaths.rulesDirectory)
        let names = RuleFileNames(
            pricing: "../pricing.json",
            calendar: base.manifest.files.calendar,
            reminderPolicy: base.manifest.files.reminderPolicy
        )
        let manifest = makeNewerManifest(base: base, fileNames: names)
        let baseURL = URL(string: "https://example.com/rules")!
        let updater = RemoteRuleUpdater(
            baseURL: baseURL,
            fetcher: FakeFetcher(payloads: [
                baseURL.appendingPathComponent("manifest.json"): try RuleJSON.makeEncoder().encode(manifest)
            ])
        )
        await #expect(throws: RuleUpdateError.self) {
            _ = try await updater.checkForUpdate(current: base.ruleSet)
        }
    }

}
