import Foundation
import Testing
@testable import LiangWenCore
@testable import LiangWenKit

@Suite("规则安装与生效")
struct RuleRepositoryTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("liangwen-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func copyBundledRules(to directory: URL) throws {
        try FileManager.default.copyItem(at: KitTestPaths.rulesDirectory, to: directory)
    }

    @Test("默认使用内置规则")
    func defaultsToBundled() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("Rules", isDirectory: true)
        try copyBundledRules(to: bundled)
        let repository = RuleRepository(
            bundledDirectory: bundled,
            supportDirectory: root.appendingPathComponent("Support", isDirectory: true)
        )
        let active = repository.active(at: KitFixture.date("2026-10-21T10:00:00+08:00"))
        #expect(active.origin == .bundled)
        #expect(active.pendingVersion == nil)
        #expect(active.installedError == nil)
        #expect(active.bundle.manifest.bundleVersion == "2026.10.23")
    }

    @Test("未来生效的规则先进入待启用区")
    func futureBundleIsPending() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("Rules", isDirectory: true)
        try copyBundledRules(to: bundled)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        let repository = RuleRepository(bundledDirectory: bundled, supportDirectory: support)

        let now = KitFixture.date("2026-10-22T10:00:00+08:00")
        let base = try RuleBundleLoader.load(from: bundled)
        let manifest = RuleBundleManifest(
            schemaVersion: 1,
            bundleVersion: "future-1",
            publishedAt: KitFixture.date("2026-10-22T12:00:00+08:00"),
            effectiveFrom: KitFixture.date("2026-10-24T00:00:00+08:00"),
            files: base.manifest.files,
            sha256: base.manifest.sha256,
            notes: nil
        )
        let future = VerifiedRuleBundle(manifest: manifest, ruleSet: base.ruleSet, files: base.files)
        try repository.install(future, at: now)

        #expect(repository.pendingVersion == "future-1")
        let active = repository.active(at: now)
        #expect(active.origin == .bundled)
        #expect(active.pendingVersion == "future-1")

        let promoted = repository.active(at: KitFixture.date("2026-10-25T00:00:00+08:00"))
        #expect(promoted.origin == .installed)
        #expect(promoted.bundle.manifest.bundleVersion == "future-1")
        #expect(repository.pendingVersion == nil)
    }

    @Test("已安装规则损坏时回退到内置规则")
    func corruptInstalledFallsBack() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("Rules", isDirectory: true)
        try copyBundledRules(to: bundled)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        let repository = RuleRepository(bundledDirectory: bundled, supportDirectory: support)

        let now = KitFixture.date("2026-10-24T10:00:00+08:00")
        let base = try RuleBundleLoader.load(from: bundled)
        try repository.install(base, at: now)
        #expect(repository.active(at: now).origin == .installed)

        let pricingURL = repository.activeDirectory
            .appendingPathComponent(base.manifest.files.pricing)
        try Data("{}".utf8).write(to: pricingURL, options: .atomic)

        let fallback = repository.active(at: now)
        #expect(fallback.origin == .bundled)
        #expect(fallback.installedError != nil)
    }
}
