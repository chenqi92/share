import SwiftUI
import MeshDropKit

struct MeTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme

    private var me: MockMe { engine.displaySelf }
    private var firstOffer: MockPendingOffer? { engine.pendingFileOffers.first?.displayMock }
    private var historyToday: Int {
        let cal = Calendar.current
        return engine.history.filter { cal.isDateInToday($0.createdAt) }.count
    }
    private var trustedCount: Int { engine.trusted.count }
    /// 来自 Share Extension、还没选目标的待发项数量（点「稍后」后用于再次进入）。
    private var pendingShareCount: Int { PendingShareQueue.shared.unresolvedItems().count }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    selfCard
                    AsciiDivider(MD("me.section.manage"))
                    actionList
                    AsciiDivider(MD("me.section.received"))
                    pendingCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { MeshDropLockup(size: 17) }
            ToolbarItem(placement: .topBarTrailing) {
                Button { state.showSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MD("me.title"))
                .font(MeshDropFont.display(28, weight: .bold))
            Text(MD("me.subtitle"))
                .font(MeshDropFont.display(18, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink60)
        }
    }

    private var selfCard: some View {
        HStack(spacing: 14) {
            Avatar(initials: "ME", color: MeshDropColor.lime.opacity(0.9),
                   size: 56, ring: .lime, online: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(me.name)
                    .font(MeshDropFont.display(20, weight: .bold))
                HStack(spacing: 6) {
                    KindGlyph(.ios, size: 11)
                    Text(me.os)
                        .font(MeshDropFont.mono(11))
                    Text("·")
                    Text(me.ip)
                        .font(MeshDropFont.mono(11))
                }
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)

                Text(me.fingerprint)
                    .font(MeshDropFont.mono(10.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.7) : MeshDropColor.ink80)
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(16)
        .liquidGlass(.rect(18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var actionList: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            actionTile(MD("me.action.history.title"), "clock.arrow.circlepath",
                       detail: MD("me.action.history.detail", historyToday)) { state.showHistory = true }
            actionTile(MD("me.action.trust.title"), "checkmark.shield",
                       detail: MD("me.action.trust.detail", trustedCount)) { state.showTrustManager = true }
            actionTile(MD("me.action.pairing.title"), "qrcode",
                       detail: MD("me.action.pairing.detail")) { state.showPairingSheet = true }
            actionTile(MD("me.action.onboarding.title"), "sparkles",
                       detail: MD("me.action.onboarding.detail")) { state.showOnboarding = true }
            actionTile(MD("me.action.settings.title"), "gearshape",
                       detail: MD("me.action.settings.detail")) { state.showSettings = true }
#if DEBUG
            actionTile(MD("me.action.shareExt.title"), "square.and.arrow.up",
                       detail: MD("me.action.shareExt.detail")) { state.showShareExt = true }
#endif
            actionTile(MD("me.action.liveActivity.title"), "clock.badge",
                       detail: MD("me.action.liveActivity.detail")) { state.showLiveActivity = true }
            if pendingShareCount > 0 {
                actionTile(MD("me.action.pendingShare.title"), "tray.and.arrow.up",
                           detail: MD("me.action.pendingShare.detail", pendingShareCount)) {
                    state.pendingShares = PendingShareQueue.shared.unresolvedItems()
                    state.showPendingShareResolver = true
                }
            }
        }
    }

    @ViewBuilder
    private func actionTile(_ title: String, _ icon: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(scheme == .dark ? Color.white.opacity(0.06) : MeshDropColor.ink06)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MeshDropFont.body(14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                    Text(detail)
                        .font(MeshDropFont.mono(10.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pendingCard: some View {
        if let offer = firstOffer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Chip("OFFER", tone: .flame, mono: true, uppercased: true)
                    Text(MD("me.offer.fromPeer", offer.peer))
                        .font(MeshDropFont.body(13, weight: .semibold))
                    Spacer()
                    Text(offer.receivedAt)
                        .font(MeshDropFont.mono(10))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                }
                if offer.isImage {
                    ImagePreview(url: nil, base64: offer.previewBase64, cornerRadius: 12)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .overlay(alignment: .bottomLeading) {
                            Text("\(offer.fileName) · \(offer.fileSize)")
                                .font(MeshDropFont.mono(10.5, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.white)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)],
                                                   startPoint: .top,
                                                   endPoint: .bottom)
                                )
                        }
                } else {
                    FileChip(name: offer.fileName,
                             size: offer.fileSize,
                             ext: (offer.fileName as NSString).pathExtension)
                }
                HStack(spacing: 8) {
                    Button { state.showOfferSheet = true } label: {
                        Text(MD("me.offer.viewAndChoose"))
                            .font(MeshDropFont.body(13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(MeshDropColor.lime))
                            .foregroundStyle(MeshDropColor.ink)
                    }
                    .buttonStyle(.plain)
                    Button {
                        if let uuid = UUID(uuidString: offer.id) {
                            engine.respondToFileOffer(uuid, accept: false)
                        }
                    } label: {
                        Text(MD("common.reject"))
                            .font(MeshDropFont.body(13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .overlay(Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )
        } else {
            HStack {
                Text(MD("me.pending.empty"))
                    .font(MeshDropFont.mono(11))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
        }
    }
}
