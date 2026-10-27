import Foundation
import OSLog

/// One-way migration of the installed-rules directory after the engineering
/// rename from LiangWen to Gudeng.
///
/// The app used to store downloaded rule bundles under
/// `Application Support/LiangWen/Rules`. The current build uses
/// `Application Support/Gudeng/Rules`. Moving instead of copying keeps the
/// verified bundle exactly as installed; a failed move falls back to a copy so
/// users do not silently lose an already verified download.
public enum RuleStorageMigration {
    public static let directoryName = "Gudeng"
    public static let legacyDirectoryName = "LiangWen"

    private static let logger = Logger(subsystem: "com.easyindie.easyapiclock", category: "rules")

    /// Returns the current support root, migrating legacy data when possible.
    @discardableResult
    public static func migrateIfNeeded(
        supportRoot: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let current = supportRoot.appendingPathComponent(directoryName, isDirectory: true)
        let legacy = supportRoot.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        guard !fileManager.fileExists(atPath: current.path),
            fileManager.fileExists(atPath: legacy.path)
        else {
            return current
        }
        do {
            try fileManager.moveItem(at: legacy, to: current)
            logger.info("已把旧规则目录迁移到 Gudeng")
        } catch {
            logger.error("迁移旧规则目录失败：\(error.localizedDescription, privacy: .public)")
            try? fileManager.copyItem(at: legacy, to: current)
        }
        return current
    }
}
