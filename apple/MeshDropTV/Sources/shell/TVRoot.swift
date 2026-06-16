import SwiftUI
import MeshDropKit

struct TVRoot: View {
    @EnvironmentObject private var engine: ShareEngine
    @State private var tab: TVTab = TVRoot.initialTab
    @State private var didAutoSwitchForOffer: UUID?

    /// 截图预览：按 MESHDROP_PREVIEW_ROUTE 决定首屏 tab；release 由 #if DEBUG 排除。
    static var initialTab: TVTab {
        #if DEBUG
        if let r = ProcessInfo.processInfo.environment["MESHDROP_PREVIEW_ROUTE"] {
            switch r {
            case "receive":              return .receive
            case "gallery", "transfers": return .gallery
            case "pairing":              return .pairing
            case "settings":             return .settings
            default:                     return .nearby
            }
        }
        #endif
        return .nearby
    }

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
                    tag: L10n.headerReceiveTag(offer.peer.name),
                    title: L10n.headerReceiveTitle(offer.peer.name),
                    titleAccentSuffix: offer.fileName
                ) {
                    HStack(spacing: 10) {
                        Chip(text: "● LAN", tone: .lime, mono: true, size: 14)
                        Chip(text: L10n.chipPlaintext, tone: .outline, mono: true, size: 14)
                    }
                }
            } else {
                PageHeader(
                    tag: L10n.headerReceiveWaitingTag,
                    title: L10n.headerReceiveWaitingTitle,
                    titleAccentSuffix: "Ready."
                ) {
                    HStack(spacing: 10) {
                        Chip(text: engineNetTag, tone: .lime, mono: true, size: 14)
                        Chip(text: L10n.chipVisibleCount(engine.devices.count), tone: .outline, mono: true, size: 14)
                    }
                }
            }
        case .nearby:
            PageHeader(
                tag: engine.devices.isEmpty ? L10n.headerNearbyScan : L10n.headerNearbyReady,
                title: L10n.headerNearbyTitle,
                titleAccentSuffix: "ping."
            ) {
                HStack(spacing: 10) {
                    Chip(text: engineNetTag, tone: .lime, mono: true, size: 14)
                    Chip(text: L10n.chipVisibleCount(engine.devices.count), tone: .outline, mono: true, size: 14)
                }
            }
        case .gallery:
            let inbox = engine.history.filter { $0.isInboxFile }
            PageHeader(
                tag: L10n.headerGalleryTag(inbox.count),
                title: L10n.headerGalleryTitle,
                titleAccentSuffix: "\(inbox.count)"
            ) {
                HStack(spacing: 12) {
                    Chip(text: "\(L10n.galleryFilterAll) · ALL", tone: .lime, mono: true, size: 14)
                    Chip(text: "\(L10n.galleryFilterPhotos) · PHOTOS", tone: .outline, mono: true, size: 14)
                    Chip(text: "\(L10n.galleryFilterFiles) · FILES", tone: .outline, mono: true, size: 14)
                }
            }
        case .pairing:
            PageHeader(
                tag: L10n.headerPairingTag,
                title: L10n.headerPairingTitle,
                titleAccentSuffix: L10n.headerPairingAccent
            ) {
                HStack(spacing: 10) {
                    Chip(text: "LAN ONLY", tone: .lime, mono: true, size: 14)
                    Chip(text: "ED25519", tone: .outline, mono: true, size: 14)
                    Chip(text: L10n.chipPendingCount(engine.pendingPairings.count), tone: .outline, mono: true, size: 14)
                }
            }
        case .settings:
            PageHeader(
                tag: L10n.headerSettingsTag,
                title: L10n.headerSettingsTitle,
                titleAccentSuffix: "Settings"
            ) {
                HStack(spacing: 10) {
                    Chip(text: "● LAN ONLY", tone: .lime, mono: true, size: 14)
                    Chip(text: L10n.chipPlaintext, tone: .outline, mono: true, size: 14)
                    Chip(text: "tvOS 17+", tone: .outline, mono: true, size: 14)
                }
            }
        }
    }

    private var engineNetTag: String {
        engine.devices.isEmpty ? L10n.netTagScanning : L10n.netTagLivingRoom
    }
}
