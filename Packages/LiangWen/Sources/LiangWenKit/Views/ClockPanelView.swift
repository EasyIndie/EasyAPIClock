import SwiftUI
import LiangWenCore

public struct ClockPanelView: View {
    @ObservedObject private var model: ClockModel
    private let onQuit: (() -> Void)?
    @State private var showingSettings = false
    @AppStorage("gudeng.appearance") private var appearance = "system"
    @AppStorage("gudeng.animations") private var animations = true
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(model: ClockModel, onQuit: (() -> Void)? = nil) {
        self.model = model
        self.onQuit = onQuit
    }

    public var body: some View {
        ZStack {
            if showingSettings {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingSettings = false
                        } label: {
                            Label(ClockText.backTitle, systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                                .frame(width: 28, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(ClockText.settingsTitle).font(.headline)
                        Spacer()
                        Color.clear.frame(width: 28, height: 32)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .frame(height: 46)
                    .layoutPriority(1)
                    Divider().padding(.horizontal, 20)
                    ScrollView {
                        SettingsPanelContent(model: model)
                    }
                    .scrollIndicators(.visible)
                    .frame(height: 275)
                    .clipped()
                }
                .frame(width: 334, height: 322, alignment: .top)
                .clipped()
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    MainPanelContent(model: model)
                        .frame(maxHeight: .infinity)
                    Divider().padding(.horizontal, 20)
                    HStack(spacing: 8) {
                        Text(ClockText.panelTransitionLine(for: model.snapshot, now: model.now))
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button {
                            showingSettings = true
                        } label: {
                            Label(ClockText.settingsTitle, systemImage: "gearshape")
                                .labelStyle(.iconOnly)
                                .font(.system(size: 19))
                                .frame(width: 32, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(ClockText.settingsTitle)
                        if let onQuit {
                            Button(action: onQuit) {
                                Label(ClockText.quitTitle, systemImage: "power")
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 17))
                                    .frame(width: 32, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(ClockText.quitTitle)
                            .accessibilityHint(ClockText.quitHint)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .transition(.opacity)
            }
        }
        .frame(width: 334, height: 322)
        .background(reduceTransparency ? AnyShapeStyle(.background) : AnyShapeStyle(.regularMaterial))
        .environment(\.colorScheme, resolvedColorScheme)
        #if os(macOS)
            .background(PanelAppearanceBridge(mode: appearance).frame(width: 0, height: 0))
        #endif
        .animation(animations && !reduceMotion ? .easeInOut(duration: 0.2) : nil, value: showingSettings)
    }
    private var resolvedColorScheme: ColorScheme {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: systemColorScheme
        }
    }
}
