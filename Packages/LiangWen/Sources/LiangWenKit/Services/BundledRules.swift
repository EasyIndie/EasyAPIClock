import Foundation
import LiangWenCore

/// Loads the rule folder copied into the app bundle by XcodeGen.
public enum BundledRules {
    public static func load(bundle: Bundle = .main) throws -> VerifiedRuleBundle {
        guard let directory = bundle.url(forResource: "Rules", withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try RuleBundleLoader.load(from: directory)
    }
}
