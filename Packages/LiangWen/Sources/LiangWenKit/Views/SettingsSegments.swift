import SwiftUI
#if os(macOS)
    import AppKit
#endif

/// A compact system segmented control with a stable, explicit layout boundary.
struct SettingsSegments: View {
    let title: String
    let titles: [String]
    @Binding var selection: Int

    var body: some View {
        #if os(macOS)
            Native(title: title, titles: titles, selection: $selection)
                .frame(width: CGFloat(titles.count) * 50, height: 24)
        #else
            Picker(title, selection: $selection) {
                ForEach(titles.indices, id: \.self) { index in
                    Text(titles[index]).tag(index)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        #endif
    }

    #if os(macOS)
        private struct Native: NSViewRepresentable {
            let title: String
            let titles: [String]
            @Binding var selection: Int
            @Environment(\.isEnabled) private var isEnabled

            func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

            func makeNSView(context: Context) -> Control {
                let control = Control()
                control.segmentStyle = .rounded
                control.trackingMode = .selectOne
                control.segmentDistribution = .fillEqually
                control.controlSize = .regular
                control.font = .systemFont(ofSize: 12)
                control.target = context.coordinator
                control.action = #selector(Coordinator.select(_:))
                return control
            }

            func updateNSView(_ control: Control, context: Context) {
                context.coordinator.selection = $selection
                if control.segmentCount != titles.count { control.segmentCount = titles.count }
                for (index, title) in titles.enumerated() {
                    control.setLabel(title, forSegment: index)
                    control.setWidth(0, forSegment: index)
                }
                control.selectedSegment = selection
                control.isEnabled = isEnabled
                control.setAccessibilityLabel(title)
            }

            final class Control: NSSegmentedControl {
                // Use the visible control frame, rather than AppKit's extra alignment outsets.
                override var alignmentRectInsets: NSEdgeInsets {
                    NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                }
            }

            final class Coordinator: NSObject {
                var selection: Binding<Int>

                init(selection: Binding<Int>) { self.selection = selection }

                @MainActor @objc func select(_ sender: NSSegmentedControl) {
                    selection.wrappedValue = sender.selectedSegment
                }
            }
        }
    #endif
}
