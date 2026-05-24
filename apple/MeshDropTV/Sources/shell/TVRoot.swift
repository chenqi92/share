import SwiftUI

struct TVRoot: View {
    @State private var tab: TVTab = .receive

    var body: some View {
        ZStack {
            MeshDropColor.ambient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Top bar：固定 112pt
                TVTopBar(selection: $tab)
                    .frame(height: 112)
                    .frame(maxWidth: .infinity)
                    .transaction { txn in txn.disablesAnimations = true }

                // 2. PageHeader：固定 96pt，由 root 渲染，所有 page 共用同一坐标系
                pageHeader
                    .padding(.horizontal, 90)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .transaction { txn in txn.disablesAnimations = true }

                // 3. Page main content：拿剩余空间
                Group {
                    switch tab {
                    case .receive:  ReceivePage()
                    case .nearby:   NearbyPage()
                    case .gallery:  GalleryPage()
                    case .pairing:  PairingPage()
                    case .settings: SettingsPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 90)
                .padding(.bottom, 50)
                .animation(nil, value: tab)
                .transaction { txn in txn.disablesAnimations = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var pageHeader: some View {
        switch tab {
        case .receive:
            PageHeader(
                tag: "接收 · RECEIVE · 来自 \(MockData.incomingPeer.who)",
                title: "孟茜想发给你 ",
                titleAccentSuffix: "18 张照片"
            ) {
                HStack(spacing: 10) {
                    Chip(text: "● E2E", tone: .lime, mono: true, size: 14)
                    Chip(text: "9MS · LAN", tone: .outline, mono: true, size: 14)
                }
            }
        case .nearby:
            PageHeader(
                tag: "附近 · NEARBY · READY 待机",
                title: "这台电视，谁都能 ",
                titleAccentSuffix: "ping."
            ) {
                HStack(spacing: 10) {
                    Chip(text: "● 客厅 LAN", tone: .lime, mono: true, size: 14)
                    Chip(text: "5 台可见", tone: .outline, mono: true, size: 14)
                }
            }
        case .gallery:
            PageHeader(
                tag: "收件箱 · LIBRARY · \(MockData.gallerySummary.count) 件 · \(MockData.gallerySummary.size)",
                title: "收件箱 ",
                titleAccentSuffix: MockData.gallerySummary.count
            ) {
                HStack(spacing: 12) {
                    Chip(text: "全部 · ALL", tone: .lime, mono: true, size: 14)
                    Chip(text: "图片 · PHOTOS", tone: .outline, mono: true, size: 14)
                    Chip(text: "文件 · FILES", tone: .outline, mono: true, size: 14)
                    Chip(text: "今天 · TODAY", tone: .outline, mono: true, size: 14)
                }
            }
        case .pairing:
            PageHeader(
                tag: "待配对 · PAIRING · 把代码发给对方",
                title: "把代码发给 ",
                titleAccentSuffix: "对方"
            ) {
                HStack(spacing: 10) {
                    Chip(text: "LAN ONLY", tone: .lime, mono: true, size: 14)
                    Chip(text: "E2E · CHACHA20", tone: .outline, mono: true, size: 14)
                    Chip(text: "65 秒后过期", tone: .outline, mono: true, size: 14)
                }
            }
        case .settings:
            PageHeader(
                tag: "设置 · SETTINGS · 可见性 · 安全 · 行为",
                title: "设置 ",
                titleAccentSuffix: "Settings"
            ) {
                HStack(spacing: 10) {
                    Chip(text: "● LAN ONLY", tone: .lime, mono: true, size: 14)
                    Chip(text: "E2E", tone: .outline, mono: true, size: 14)
                    Chip(text: "tvOS 17+", tone: .outline, mono: true, size: 14)
                }
            }
        }
    }
}
