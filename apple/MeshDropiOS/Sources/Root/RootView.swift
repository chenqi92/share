import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if hSize == .regular {
                PadRoot()
            } else {
                PhoneRoot()
            }
        }
        .background(scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
    }
}
