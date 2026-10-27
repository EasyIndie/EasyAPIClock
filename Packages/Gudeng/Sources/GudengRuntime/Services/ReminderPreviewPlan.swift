import Foundation
import GudengCore

/// Preview timing is local UI policy, separate from real price events.
public struct ReminderPreviewPlan: Sendable, Equatable {
    public let offsets: [TimeInterval]
    public let duration: TimeInterval

    public init(intensity: ReminderIntensity) {
        switch intensity {
        case .off: offsets = []; duration = 0
        case .medium: offsets = [1]; duration = 10
        case .strong: offsets = [1, 4, 7]; duration = 10
        }
    }

    public func identifiers(id: String) -> [String] {
        offsets.indices.map { "gudeng.preview.\(id).\($0)" }
    }
}
