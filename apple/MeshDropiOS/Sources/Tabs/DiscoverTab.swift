import SwiftUI
import MeshDropKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct DiscoverTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme
    @State private var showFileImporter: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var quickNotice: QuickNotice?
    @State private var quickStatus: String?

    private var devices: [MockDevice] { engine.displayDevices }
    private var me: MockMe { engine.displaySelf }
    private var quickTarget: Device? {
        engine.devices.first(where: { $0.id == state.selectedDeviceID }) ?? engine.devices.first
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    if let err = engine.lastError {
                        errorBanner(err)
                    }
                    heroBlock
                    radarBlock
                    quickStripBlock
                    deviceListBlock
                    AsciiDivider("LAN · \(me.ip)/24 · \(engine.isStarting ? "SCANNING" : "LIVE")")
                    statusBar
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                sendPickedFiles(urls)
            case .failure(let error):
                quickNotice = QuickNotice(title: MD("discovery.fileUnreadable.title"), message: error.localizedDescription)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $photoSelection,
                      maxSelectionCount: 0,
                      matching: .images)
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            Task { await sendPickedPhotos(items) }
        }
        .onChange(of: quickStatus) { _, value in
            guard let value else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if quickStatus == value { quickStatus = nil }
            }
        }
        .alert(item: $quickNotice) { notice in
            Alert(title: Text(notice.title),
                  message: Text(notice.message),
                  dismissButton: .default(Text(MD("common.ok"))))
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            MeshDropLockup(size: 18)
            Spacer()
            Chip(engine.isStarting ? "SCAN" : "LIVE",
                 tone: engine.isStarting ? .flame : .lime,
                 mono: true, uppercased: true, icon: "circle.fill")
            IconBtn("line.3.horizontal", size: 32, variant: .ghost) {
                state.showSettings = true
            }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MeshDropColor.flame)
            Text(MD("discovery.error", msg))
                .font(MeshDropFont.mono(11))
                .lineLimit(2)
            Spacer()
            Button("×") { engine.clearLastError() }
                .font(MeshDropFont.mono(14, weight: .bold))
                .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeshDropColor.flame.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(MeshDropColor.flame.opacity(0.6), lineWidth: 0.5)
        )
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MD("discovery.title"))
                    .font(MeshDropFont.display(34, weight: .bold))
                Text(MD("discovery.deviceCount", devices.filter(\.isOnline).count))
                    .font(MeshDropFont.mono(14, weight: .semibold))
                    .foregroundStyle(MeshDropColor.flame)
            }
            HStack(spacing: 6) {
                Text(MD("discovery.subtitle"))
                    .font(MeshDropFont.display(20, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                Spacer()
            }
            Text(engine.isStarting ? "scanning · \(me.ip)/24 · LAN ONLY" : "ready · \(me.ip)/24 · LAN ONLY")
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                .tracking(0.5)
                .padding(.top, 2)
        }
    }

    private var radarBlock: some View {
        HStack {
            Spacer()
            Radar(devices: devices.filter(\.isOnline), mode: .sweep,
                  selectedDevice: state.selectedDeviceDisplay(engine: engine),
                  meIP: me.ip, diameter: 300)
            Spacer()
        }
    }

    @ViewBuilder
    private var deviceListBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsciiDivider("DEVICES · \(devices.count)")
            if devices.isEmpty {
                emptyDeviceCard
            } else {
                ForEach(devices) { d in
                    DeviceCard(d, selected: state.selectedDeviceID == d.id)
                        .onTapGesture {
                            state.selectedDeviceID = d.id
                            state.phoneTab = .chats
                        }
                        .contextMenu {
                            Button(MD("discovery.menu.send")) {
                                state.selectedDeviceID = d.id
                                state.presentSend(.text)
                            }
                            Button(MD("discovery.menu.viewProfile")) {}
                            Button(MD("discovery.menu.mute")) {}
                            Divider()
                            Button(MD("discovery.menu.revokeTrust"), role: .destructive) {
                                if let real = engine.realDevice(for: d.id) {
                                    engine.revokeTrust(fingerprint: real.fingerprint)
                                }
                            }
                        }
                }
            }
        }
    }

    private var emptyDeviceCard: some View {
        VStack(spacing: 8) {
            Text(MD("discovery.devices.empty.title"))
                .font(MeshDropFont.body(13.5, weight: .semibold))
            Text(MD("discovery.devices.empty.subtitle"))
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var quickStripBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider(MD("discovery.quick.sectionTitle"))
            HStack(spacing: 10) {
                quickItem(MD("discovery.quick.text"),      "text.alignleft",  variant: .ink, action: openQuickText)
                quickItem(MD("discovery.quick.clipboard"), "doc.on.clipboard", variant: .ghost, action: sendClipboardNow)
                quickItem(MD("discovery.quick.photo"),     "photo.on.rectangle", variant: .ghost, action: openPhotoPickerNow)
                quickItem(MD("discovery.quick.file"),      "folder",         variant: .ghost, action: openFilePickerNow)
            }
            if let quickStatus {
                Text(quickStatus)
                    .font(MeshDropFont.mono(10.5, weight: .semibold))
                    .foregroundStyle(MeshDropColor.limeDeep)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func quickItem(_ label: String, _ symbol: String, variant: IconBtn.Variant, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                IconBtn(symbol, size: 44, variant: variant, shape: .square, wrapInButton: false)
                Text(label)
                    .font(MeshDropFont.body(11, weight: .medium))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openQuickText() {
        guard let target = ensureQuickTarget() else { return }
        state.selectedDeviceID = target.id
        state.presentSend(.text, allowsKindSwitch: false)
    }

    private func sendClipboardNow() {
        guard let target = ensureQuickTarget() else { return }
        let content = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            quickNotice = QuickNotice(title: MD("discovery.quickTarget.clipboardEmpty.title"), message: MD("discovery.quickTarget.clipboardEmpty.message"))
            return
        }
        engine.pushClipboard(to: target, content: content, kind: ClipboardTab.clipKind(content))
        showQuickSuccess(MD("discovery.quickStatus.clipboardSent", target.name))
    }

    private func openPhotoPickerNow() {
        guard let target = ensureQuickTarget() else { return }
        state.selectedDeviceID = target.id
        showPhotoPicker = true
    }

    private func openFilePickerNow() {
        guard let target = ensureQuickTarget() else { return }
        state.selectedDeviceID = target.id
        showFileImporter = true
    }

    private func ensureQuickTarget() -> Device? {
        guard let target = quickTarget else {
            quickNotice = QuickNotice(title: MD("discovery.quickTarget.noDevice.title"), message: MD("discovery.quickTarget.noDevice.message"))
            return nil
        }
        state.selectedDeviceID = target.id
        return target
    }

    private func sendPickedFiles(_ urls: [URL]) {
        guard let target = ensureQuickTarget(), !urls.isEmpty else { return }
        urls.forEach { engine.sendFile(to: target, sourceURL: $0) }
        showQuickSuccess(MD("discovery.quickStatus.filesSent", urls.count, target.name))
    }

    private func sendPickedPhotos(_ items: [PhotosPickerItem]) async {
        defer { photoSelection = [] }
        guard let target = ensureQuickTarget() else { return }
        var sent = 0
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first(where: { $0.preferredFilenameExtension != nil })?
                .preferredFilenameExtension ?? "jpg"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMG-\(UUID().uuidString).\(ext)")
            do {
                try data.write(to: url)
                engine.sendFile(to: target, sourceURL: url)
                sent += 1
            } catch {
                continue
            }
        }
        if sent > 0 {
            showQuickSuccess(MD("discovery.quickStatus.photosSent", sent, target.name))
        } else {
            quickNotice = QuickNotice(title: MD("discovery.photosUnreadable.title"), message: MD("discovery.photosUnreadable.message"))
        }
    }

    private func showQuickSuccess(_ message: String) {
        quickStatus = message
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Chip("LAN ONLY", tone: .outline, mono: true, uppercased: true)
            Chip(engine.isStarting ? MD("discovery.status.scanning") : MD("discovery.status.visible"),
                 tone: .lime,
                 mono: true, uppercased: true,
                 icon: engine.isStarting ? "circle.dotted" : "eye.fill")
            Spacer()
            Text(me.fingerprint.prefix(11))
                .font(MeshDropFont.mono(10))
                .tracking(0.5)
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
        }
    }
}

private struct QuickNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
