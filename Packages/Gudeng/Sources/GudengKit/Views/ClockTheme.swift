import SwiftUI
import GudengCore

/// Brand and price roles remain separate from system control/selection colors.
enum ClockTheme {
    static func brand(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.61, green: 0.71, blue: 1) : Color(red: 0.20, green: 0.29, blue: 0.70)
    }

    static func price(_ state: PriceState?, scheme: ColorScheme) -> Color {
        switch state {
        case .valley:
            scheme == .dark ? Color(red: 0.40, green: 0.91, blue: 0.81) : Color(red: 0, green: 0.39, blue: 0.35)
        case .peak:
            scheme == .dark ? Color(red: 1, green: 0.67, blue: 0.51) : Color(red: 0.61, green: 0.23, blue: 0.09)
        case nil: .secondary
        }
    }
}
