import SwiftUI
import UIKit

struct NightInviteLink<Label: View>: View {
    let boardName: String
    let code: String
    let link: URL
    @ViewBuilder let label: () -> Label

    var body: some View {
        ShareLink(
            item: link,
            subject: Text("join \(boardName) on resona"),
            message: Text("join \(boardName) on resona. the code is \(code)."),
            preview: SharePreview("\(boardName) on resona", image: Self.appIcon),
            label: label
        )
    }

    static var appIcon: Image {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let name = (primary?["CFBundleIconFiles"] as? [String])?.last
        return name.flatMap { UIImage(named: $0) }.map(Image.init(uiImage:)) ?? Image(systemName: "person.2.fill")
    }
}
