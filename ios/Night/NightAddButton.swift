import SwiftUI

struct NightAddButton: View {
    var body: some View {
        AddMenu()
            .menuStyle(.button)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.extraLarge)
            .font(.title.weight(NightStyle.symbolWeight))
            .foregroundStyle(.white)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
