import CryptoKit
import Foundation

public struct RuleFileNames: Sendable, Equatable, Codable {
    public let pricing: String
    public let calendar: String
    public let reminderPolicy: String

    public init(pricing: String, calendar: String, reminderPolicy: String) {
        self.pricing = pricing
        self.calendar = calendar
        self.reminderPolicy = reminderPolicy
    }

    public var all: [String] { [pricing, calendar, reminderPolicy] }
}

public struct RuleChecksums: Sendable, Equatable, Codable {
    public let pricing: String
    public let calendar: String
    public let reminderPolicy: String

    public init(pricing: String, calendar: String, reminderPolicy: String) {
        self.pricing = pricing
        self.calendar = calendar
        self.reminderPolicy = reminderPolicy
    }

    public var all: [String] { [pricing, calendar, reminderPolicy] }
}

/// Describes a complete, self-contained rule bundle.
///
/// A bundle is replaced as a unit. The checksums protect against truncated
/// downloads and accidental edits; they are not a signature.
public struct RuleBundleManifest: Sendable, Equatable, Codable {
    public let schemaVersion: Int
    public let bundleVersion: String
    public let publishedAt: Date
    public let effectiveFrom: Date
    public let files: RuleFileNames
    public let sha256: RuleChecksums
    public let notes: String?

    public init(
        schemaVersion: Int,
        bundleVersion: String,
        publishedAt: Date,
        effectiveFrom: Date,
        files: RuleFileNames,
        sha256: RuleChecksums,
        notes: String?
    ) {
        self.schemaVersion = schemaVersion
        self.bundleVersion = bundleVersion
        self.publishedAt = publishedAt
        self.effectiveFrom = effectiveFrom
        self.files = files
        self.sha256 = sha256
        self.notes = notes
    }
}

public struct VerifiedRuleBundle: Sendable, Equatable {
    public let manifest: RuleBundleManifest
    public let ruleSet: RuleSet
    /// The exact file bytes, kept so the app can install the bundle atomically.
    public let files: [String: Data]

    public init(manifest: RuleBundleManifest, ruleSet: RuleSet, files: [String: Data]) {
        self.manifest = manifest
        self.ruleSet = ruleSet
        self.files = files
    }
}

public enum RuleBundleLoader {
    public static func load(from directory: URL) throws -> VerifiedRuleBundle {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try RuleJSON.makeDecoder().decode(RuleBundleManifest.self, from: manifestData)
        var files: [String: Data] = [:]
        for name in manifest.files.all {
            guard isSafeFileName(name) else {
                throw RuleValidationError(["规则文件名不安全：\(name)"])
            }
            files[name] = try Data(contentsOf: directory.appendingPathComponent(name))
        }
        return try load(manifestData: manifestData, files: files)
    }

    public static func load(manifestData: Data, files: [String: Data]) throws -> VerifiedRuleBundle {
        let manifest: RuleBundleManifest
        do {
            manifest = try RuleJSON.makeDecoder().decode(RuleBundleManifest.self, from: manifestData)
        } catch {
            throw RuleValidationError(["manifest.json 解析失败：\(error.localizedDescription)"])
        }

        var issues: [String] = []
        if manifest.schemaVersion != RuleValidator.supportedSchemaVersion {
            issues.append(
                "manifest schemaVersion=\(manifest.schemaVersion)，仅支持 \(RuleValidator.supportedSchemaVersion)。")
        }
        if manifest.bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("manifest bundleVersion 不能为空。")
        }

        let expectedNames = manifest.files.all
        var seen = Set<String>()
        for name in expectedNames {
            if !isSafeFileName(name) {
                issues.append("规则文件名不安全：\(name)")
            }
            if !seen.insert(name).inserted {
                issues.append("规则文件名重复：\(name)")
            }
        }
        let extraNames = Set(files.keys).subtracting(expectedNames)
        if !extraNames.isEmpty {
            issues.append("更新包含未声明的文件：\(extraNames.sorted().joined(separator: ", "))")
        }

        let checksums = manifest.sha256.all
        for (index, name) in expectedNames.enumerated() {
            guard let data = files[name] else {
                issues.append("缺少规则文件：\(name)")
                continue
            }
            let actual = sha256Hex(data).lowercased()
            let expected = checksums[index].lowercased()
            if actual != expected {
                issues.append("规则文件校验失败：\(name)（期望 \(expected)，实际 \(actual)）。")
            }
        }
        guard issues.isEmpty else { throw RuleValidationError(issues) }

        let decoder = RuleJSON.makeDecoder()
        let pricing: PricingRules
        let calendar: CalendarRules
        let policy: ReminderPolicy
        do {
            pricing = try decoder.decode(PricingRules.self, from: files[manifest.files.pricing]!)
            calendar = try decoder.decode(CalendarRules.self, from: files[manifest.files.calendar]!)
            policy = try decoder.decode(ReminderPolicy.self, from: files[manifest.files.reminderPolicy]!)
        } catch {
            throw RuleValidationError(["规则文件解析失败：\(error.localizedDescription)"])
        }

        let ruleSet = RuleSet(
            pricing: pricing,
            calendar: calendar,
            reminderPolicy: policy,
            bundleVersion: manifest.bundleVersion,
            publishedAt: manifest.publishedAt,
            effectiveFrom: manifest.effectiveFrom
        )
        try RuleValidator.validate(ruleSet)
        return VerifiedRuleBundle(manifest: manifest, ruleSet: ruleSet, files: files)
    }

    public static func isSafeFileName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix(".") else { return false }
        guard !name.contains("/"), !name.contains("\\"), !name.contains("..") else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "-_."))
                .contains(scalar)
        }
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
