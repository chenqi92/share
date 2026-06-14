import SwiftUI
import MeshDropKit

struct TVRoot: View {
    @EnvironmentObject private var engine: ShareEngine
    @State private var tab: TVTab = .nearby
    @State private var didAutoSwitchForOffer: UUID?

    var body: some View {
        ZStack {
            MeshDropColor.ambient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TVTopBar(selection: $tab, deviceCount: engine.devices.count)
                    .frame(height: 112)
                    .frame(maxWidth: .infinity)
                    .transaction { txn in txn.disablesAnimations = true }

                pageHeader
                    .padding(.horizontal, 90)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .transaction { txn in txn.disablesAnimations = true }

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
        // 有新 incoming offer 时自动跳到 receive tab
        .onChange(of: engine.pendingFileOffers.first?.id) { _, newOfferId in
            guard let newOfferId, newOfferId != didAutoSwitchForOffer else { return }
            didAutoSwitchForOffer = newOfferId
            tab = .receive
        }
    }

    @ViewBuilder
    private var pageHeader: some View {
        switch tab {
        case .receive:
            if let offer = engine.pendingFileOffers.first {
                PageHeader(
                    tag: "接收 · RECEIVE · 来自 \(offer.peer.name)",
                    title: "\(offer.peer.name) 想发给你 ",
                    titleAccentSuffix: offer.fileName
                ) {
                    HStack(spacing: 10) {
                        Chip(text: "● LAN", tone: .lime, mono: true, size: 14)
                        Chip(text: "明文 · v0.1", tone: .outline, mono: true, size: 14)
                    }
                }
            } else {
                PageHeader(
                    tag: "接收 · RECEIVE · 等候中",
                    title: "等手机推过来 ",
                    titleAccentSuffix: "Ready."
                ) {
                    HStack(spacing: 10) {
                        Chip(text: engineNetTag, tone: .lime, mono: true, size: 14)
                        Chip(text: "\(engine.devices.count) 台可见", tone: .outline, mono: true, size: 14)
                    }
                }
            }
        case .nearby:
            PageHeader(
                tag: "附近 · NEARBY · \(engine.devices.isEmpty ? "扫描中" : "READY 待机")",
                title: "这台电视，谁都能 ",
                titleAccentSuffix: "ping."
            ) {
                HStack(spacing: 10) {
                    Chip(text: engineNetTag, tone: .lime, mono: true, size: 14)
                    Chip(text: "\(engine.devices.count) 台可见", tone: .outline, mono: true, size: 14)
                }
            }
        case .gallery:
            let inbox = engine.history.filter { $0.isInboxFile }
            PageHeader(
                tag: "收件箱 · LIBRARY · \(inbox.count) 件",
                title: "收件箱 ",
                titleAccentSuffix: "\(inbox.count)"
            ) {
                HStack(spacing: 12) {
                    Chip(text: "全部 · ALL", tone: .lime, mono: true, size: 14)
                    Chip(text: "图片 · PHOTOS", tone: .outline, mono: true, size: 14)
                    Chip(text: "文件 · FILES", tone: .outline, mono: true, size: 14)
                }
            }
        case .pairing:
            PageHeader(
                tag: "待配对 · PAIRING · 比对指纹",
                title: "把代码发给 ",
                titleAccentSuffix: "对方"
            ) {
                HStack(spacing: 10) {
                    Chip(text: "LAN ONLY", tone: .lime, mono: true, size: 14)
                    Chip(text: "ED25519 指纹", tone: .outline, mono: true, size: 14)
                    Chip(text: "\(engine.pendingPairings.count) 待审", tone: .outline, mono: true, size: 14)
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
                    Chip(text: "明文 · v0.1", tone: .outline, mono: true, size: 14)
                    Chip(text: "tvOS 17+", tone: .outline, mono: true, size: 14)
                }
            }
        }
    }

    private var engineNetTag: String {
        engine.devices.isEmpty ? "● 扫描中" : "● 客厅 LAN"
    }
}
