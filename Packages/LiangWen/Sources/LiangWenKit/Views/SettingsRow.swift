import SwiftUI

struct SettingsRow<Control: View>: View {
    let title: String
    let control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            control
        }
        .frame(minHeight: 28)
    }
}
