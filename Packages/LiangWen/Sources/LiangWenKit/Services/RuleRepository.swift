import Foundation
import LiangWenCore

/// Installed rules live beside the app, with the bundled bundle as a fallback.
///
/// Layout:
/// `<support>/active/`    — the currently effective download
/// `<support>/pending/`   — a verified download whose effectiveFrom is in the future
public final class RuleRepository: Sendable {
    public enum Origin: String, Sendable, Equatable {
        case bundled
        case installed
    }

    public struct Active: Sendable, Equatable {
        public let bundle: VerifiedRuleBundle
        public let origin: Origin
        public let pendingVersion: String?
        public let installedError: String?

        public init(bundle: VerifiedRuleBundle, origin: Origin, pendingVersion: String?, installedError: String?) {
            self.bundle = bundle
            self.origin = origin
            self.pendingVersion = pendingVersion
            self.installedError = installedError
        }
    }

    private let bundledDirectory: URL
    private let supportDirectory: URL

    public init(bundledDirectory: URL, supportDirectory: URL) {
        self.bundledDirectory = bundledDirectory
        self.supportDirectory = supportDirectory
    }

    public var activeDirectory: URL { supportDirectory.appendingPathComponent("active", isDirectory: true) }
    public var pendingDirectory: URL { supportDirectory.appendingPathComponent("pending", isDirectory: true) }

    public func active(at now: Date) -> Active {
        promotePendingIfDue(at: now)

        var installedError: String?
        if FileManager.default.fileExists(atPath: activeDirectory.path) {
            do {
                let installed = try RuleBundleLoader.load(from: activeDirectory)
                return Active(
                    bundle: installed,
                    origin: .installed,
                    pendingVersion: pendingVersion,
                    installedError: nil
                )
            } catch {
                installedError = error.localizedDescription
            }
        }

        do {
            let bundled = try RuleBundleLoader.load(from: bundledDirectory)
            return Active(
                bundle: bundled,
                origin: .bundled,
                pendingVersion: pendingVersion,
                installedError: installedError
            )
        } catch {
            // Bundled rules are validated in CI and copied into the app bundle.
            // Reaching this point means the app was packaged incorrectly.
            preconditionFailure("内置规则无效：\(error)")
        }
    }

    public var pendingVersion: String? {
        guard FileManager.default.fileExists(atPath: pendingDirectory.path) else { return nil }
        return (try? RuleBundleLoader.load(from: pendingDirectory))?.manifest.bundleVersion
    }

    /// Installs a verified bundle atomically. Future-effective bundles go to pending.
    public func install(_ bundle: VerifiedRuleBundle, at now: Date) throws {
        let useActive = bundle.manifest.effectiveFrom <= now
        let target = useActive ? activeDirectory : pendingDirectory
        let staging = supportDirectory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            let manifestData = try RuleJSON.makeEncoder().encode(bundle.manifest)
            try manifestData.write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
            for name in bundle.manifest.files.all {
                guard RuleBundleLoader.isSafeFileName(name), let data = bundle.files[name] else {
                    throw RuleUpdateError.unsafeFileName(name)
                }
                try data.write(to: staging.appendingPathComponent(name), options: .atomic)
            }
            _ = try RuleBundleLoader.load(from: staging)
            try replaceDirectory(at: target, with: staging)
            if useActive {
                try? fileManager.removeItem(at: pendingDirectory)
            }
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func promotePendingIfDue(at now: Date) {
        guard FileManager.default.fileExists(atPath: pendingDirectory.path) else { return }
        guard let pending = try? RuleBundleLoader.load(from: pendingDirectory),
            pending.manifest.effectiveFrom <= now
        else {
            return
        }
        try? install(pending, at: now)
    }

    private func replaceDirectory(at target: URL, with staging: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.moveItem(at: staging, to: target)
    }
}
