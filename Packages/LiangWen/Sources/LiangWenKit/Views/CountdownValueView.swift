import SwiftUI

/// Keep duration units visible beside the digits so this cannot be read as a clock time.
struct CountdownValueView: View {
    let display: ClockText.CountdownDisplay
    @AppStorage("gudeng.animations") private var animations = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if #available(macOS 14.0, iOS 17.0, *) {
                Text(styledValue).contentTransition(.numericText())
            } else {
                Text(styledValue)
            }
        }
        .animation(animations && !reduceMotion ? .easeInOut(duration: 0.24) : nil, value: display.value)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(height: 72)
    }

    private var styledValue: AttributedString {
        var result = AttributedString()
        let hasUnits = display.value.contains("小时") || display.value.contains("分") || display.value.contains("天")
        for character in display.value {
            var fragment = AttributedString(String(character))
            fragment.font = .system(
                size: hasUnits ? (character.isNumber ? 52 : 18) : 38,
                weight: character.isNumber ? .semibold : .medium)
            result.append(fragment)
        }
        return result
    }
}
