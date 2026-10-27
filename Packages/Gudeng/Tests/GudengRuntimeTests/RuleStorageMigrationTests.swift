import Foundation
import Testing
import GudengRuntime

@Suite("规则目录迁移")
struct RuleStorageMigrationTests {
    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gudeng-migration-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("旧 LiangWen 目录整体迁移到 Gudeng")
    func migratesLegacyDirectory() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent(RuleStorageMigration.legacyDirectoryName, isDirectory: true)
        let manifest = legacy.appendingPathComponent("Rules/active/manifest.json")
        try FileManager.default.createDirectory(
            at: manifest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"bundleVersion\":\"2026.10.23\"}".utf8).write(to: manifest)

        let current = RuleStorageMigration.migrateIfNeeded(supportRoot: root)

        #expect(current.lastPathComponent == RuleStorageMigration.directoryName)
        #expect(
            FileManager.default.fileExists(
                atPath: manifest.path.replacingOccurrences(
                    of: "/\(RuleStorageMigration.legacyDirectoryName)/", with: "/\(RuleStorageMigration.directoryName)/"
                )))
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test("已有新目录时不覆盖也不删除旧目录")
    func keepsBothWhenCurrentExists() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent(RuleStorageMigration.legacyDirectoryName, isDirectory: true)
        let current = root.appendingPathComponent(RuleStorageMigration.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)

        let resolved = RuleStorageMigration.migrateIfNeeded(supportRoot: root)

        #expect(resolved == current)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
    }
}
