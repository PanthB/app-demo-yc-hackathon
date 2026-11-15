import SwiftUI

struct NightToastItem: Equatable {
    let id: UUID
    let text: String
}

struct NightToast: View {
    let text: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Text(text)
                .font(NightStyle.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHint("shows it on the board")
        .accessibilityIdentifier("nightArrivalToast")
    }
}
