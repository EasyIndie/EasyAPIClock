import Foundation
import LiangWenCore

@main
struct RuleTool {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            exit(2)
        }
        do {
            switch command {
            case "validate":
                let directory = URL(fileURLWithPath: arguments.dropFirst().first ?? "Rules")
                try validate(directory: directory)
            case "manifest":
                let directory = URL(fileURLWithPath: arguments.dropFirst().first ?? "Rules")
                let options = Array(arguments.dropFirst().dropFirst())
                try writeManifest(directory: directory, options: options)
            case "help", "--help", "-h":
                printUsage()
            default:
                FileHandle.standardError.write(Data("未知命令：\(command)\n".utf8))
                printUsage()
                exit(2)
            }
        } catch {
            FileHandle.standardError.write(Data("错误：\(error)\n".utf8))
            exit(1)
        }
    }

    private static func validate(directory: URL) throws {
        let bundle = try RuleBundleLoader.load(from: directory)
        let rules = bundle.ruleSet
        let comparison = PriceComparison(models: rules.pricing.models)
        print("规则包：\(rules.bundleVersion)（发布于 \(dateText(rules.publishedAt))）")
        print("价格规则：\(rules.pricing.version)，生效于 \(dateText(rules.pricing.effectiveFrom))")
        print("日期规则：\(rules.calendar.version)，覆盖 \(rules.calendar.coverage.from) 至 \(rules.calendar.coverage.through)")
        print("提醒策略：\(rules.reminderPolicy.version)，默认 \(rules.reminderPolicy.defaultIntensity.rawValue)")
        print("模型数量：\(rules.pricing.models.count)")
        switch comparison.kind {
        case .uniform(let multiple):
            let percent = comparison.valleyPercentLower.map { NSDecimalNumber(decimal: $0).stringValue } ?? "-"
            print("价格关系：峰期为谷期的 \(NSDecimalNumber(decimal: multiple).stringValue) 倍，谷期低 \(percent)%")
        case .mixed:
            print("价格关系：各计费项倍率不一致，界面只显示峰/谷")
        }
        print("校验通过。")
    }

    private static func writeManifest(directory: URL, options: [String]) throws {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        var manifest = try RuleJSON.makeDecoder().decode(RuleBundleManifest.self, from: data)

        var index = 0
        while index < options.count {
            let key = options[index]
            let value = index + 1 < options.count ? options[index + 1] : nil
            switch key {
            case "--bundle-version":
                guard let value else { throw ToolError.missingValue(key) }
                manifest = RuleBundleManifest(
                    schemaVersion: manifest.schemaVersion,
                    bundleVersion: value,
                    publishedAt: manifest.publishedAt,
                    effectiveFrom: manifest.effectiveFrom,
                    files: manifest.files,
                    sha256: manifest.sha256,
                    notes: manifest.notes
                )
                index += 2
            case "--published-at":
                guard let value, let date = ISO8601DateFormatter().date(from: value) else {
                    throw ToolError.invalidDate(key)
                }
                manifest = RuleBundleManifest(
                    schemaVersion: manifest.schemaVersion,
                    bundleVersion: manifest.bundleVersion,
                    publishedAt: date,
                    effectiveFrom: manifest.effectiveFrom,
                    files: manifest.files,
                    sha256: manifest.sha256,
                    notes: manifest.notes
                )
                index += 2
            case "--effective-from":
                guard let value, let date = ISO8601DateFormatter().date(from: value) else {
                    throw ToolError.invalidDate(key)
                }
                manifest = RuleBundleManifest(
                    schemaVersion: manifest.schemaVersion,
                    bundleVersion: manifest.bundleVersion,
                    publishedAt: manifest.publishedAt,
                    effectiveFrom: date,
                    files: manifest.files,
                    sha256: manifest.sha256,
                    notes: manifest.notes
                )
                index += 2
            default:
                throw ToolError.unknownOption(key)
            }
        }

        var hashes: [String] = []
        for name in manifest.files.all {
            guard RuleBundleLoader.isSafeFileName(name) else {
                throw RuleUpdateError.unsafeFileName(name)
            }
            let data = try Data(contentsOf: directory.appendingPathComponent(name))
            hashes.append(RuleBundleLoader.sha256Hex(data))
        }
        let checksums = RuleChecksums(
            pricing: hashes[0],
            calendar: hashes[1],
            reminderPolicy: hashes[2]
        )
        let updated = RuleBundleManifest(
            schemaVersion: manifest.schemaVersion,
            bundleVersion: manifest.bundleVersion,
            publishedAt: manifest.publishedAt,
            effectiveFrom: manifest.effectiveFrom,
            files: manifest.files,
            sha256: checksums,
            notes: manifest.notes
        )
        let encoded = try RuleJSON.makeEncoder().encode(updated)
        try encoded.write(to: manifestURL, options: .atomic)
        _ = try RuleBundleLoader.load(from: directory)
        print("已更新 manifest.json 校验和：\(manifest.bundleVersion)")
    }

    private static func dateText(_ date: Date) -> String {
        RuleDate.formatted(date)
    }

    private static func printUsage() {
        print(
            """
            用法：
              liangwen-rules validate <规则目录>   校验规则包
              liangwen-rules manifest <规则目录> [--bundle-version V] [--published-at ISO8601] [--effective-from ISO8601]
                                                   重新计算并写入文件校验和
            """
        )
    }
}

private enum ToolError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidDate(String)
    case unknownOption(String)

    var description: String {
        switch self {
        case .missingValue(let key): "\(key) 缺少参数值"
        case .invalidDate(let key): "\(key) 需要 ISO8601 时间，例如 2026-10-23T10:00:00+08:00"
        case .unknownOption(let key): "未知参数：\(key)"
        }
    }
}
