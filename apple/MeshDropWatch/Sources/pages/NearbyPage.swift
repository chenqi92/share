import SwiftUI
import WatchKit

struct NearbyPage: View {
    /// 运行时由 RootView 注入；Preview 走默认 .shared。
    @ObservedObject var proxy: WatchEngineProxy = .shared

    /// Preview / 调试用：直接喂一组 VM 跳过 proxy。
    var debugDevices: [WatchDeviceVM]? = nil

    @State private var focusIndex: Int = 0
    @State private var selectedIDs: Set<String> = []
    @State private var alertText: String = ""
    @State private var alertShown: Bool = false
    @State private var crownValue: Double = 0
    /// 发送进行中：避免重复派发命令。
    @State private var isSending: Bool = false
    /// 待发文本的目标 peer（非 nil 时弹出文本输入 sheet）。
    @State private var sendTarget: WatchDeviceVM? = nil

    private var devices: [WatchDeviceVM] {
        debugDevices ?? proxy.devices.map(WatchDeviceVM.init(bridge:))
    }

    private var isOffline: Bool { debugDevices == nil && !proxy.isOnline }

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            ScrollViewReader { scroll in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerBar
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                        title
                            .padding(.horizontal, 12)
                        hint
                            .padding(.horizontal, 12)
                            .padding(.top, 2)
                            .padding(.bottom, 8)

                        if isOffline {
                            offlineCard
                                .padding(.horizontal, 8)
                        } else if devices.isEmpty {
                            emptyCard
                                .padding(.horizontal, 8)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(Array(devices.enumerated()), id: \.element.id) { idx, d in
                                    row(device: d, isFocused: idx == focusIndex, isSelected: selectedIDs.contains(d.id))
                                        .id(idx)
                                        .onTapGesture { handleTap(idx: idx, device: d) }
                                        .onLongPressGesture(minimumDuration: 0.4) { handleLongPress(idx: idx, device: d) }
                                }
                            }
                            .padding(.horizontal, 8)
                        }

                        Spacer(minLength: 4)
                        footer
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                    }
                }
                .focusable(true)
                .digitalCrownRotation(
                    $crownValue,
                    from: 0,
                    through: Double(max(devices.count - 1, 0)),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: crownValue) { _, newValue in
                    let idx = max(0, min(devices.count - 1, Int(newValue.rounded())))
                    if idx != focusIndex {
                        focusIndex = idx
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            scroll.scrollTo(idx, anchor: .center)
                        }
                    }
                }
            }
        }
        .alert(alertText, isPresented: $alertShown) { Button(L10n.commonOK, role: .cancel) {} }
        .sheet(item: $sendTarget) { target in
            SendTextSheet(peerName: target.who) { text in
                sendTarget = nil
                send(text: text, to: target)
            } onCancel: {
                sendTarget = nil
            }
        }
    }

    private func handleTap(idx: Int, device d: WatchDeviceVM) {
        guard !isOffline else { return }
        focusIndex = idx
        if selectedIDs.isEmpty {
            // 单击未进入多选态：进发文本入口（watch 上发文本最自然，文件靠 iPhone）。
            WKInterfaceDevice.current().play(.click)
            sendTarget = d
        } else {
            // 已有多选：单击切换该项选中状态。
            if selectedIDs.contains(d.id) { selectedIDs.remove(d.id) } else { selectedIDs.insert(d.id) }
            WKInterfaceDevice.current().play(.click)
            alertText = L10n.nearbySelectedCount(selectedIDs.count)
            alertShown = true
        }
    }

    /// 通过桥接把文本发给指定 peer，回调里反馈结果。
    private func send(text: String, to d: WatchDeviceVM) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        Task { @MainActor in
            isSending = true
            defer { isSending = false }
            do {
                try await proxy.sendText(to: d.id, text: trimmed)
                WKInterfaceDevice.current().play(.success)
                alertText = L10n.nearbySent(d.who)
            } catch {
                WKInterfaceDevice.current().play(.failure)
                alertText = L10n.nearbySendFailed(proxy.lastError ?? error.localizedDescription)
            }
            alertShown = true
        }
    }

    private func handleLongPress(idx: Int, device d: WatchDeviceVM) {
        guard !isOffline else { return }
        focusIndex = idx
        if selectedIDs.contains(d.id) { selectedIDs.remove(d.id) } else { selectedIDs.insert(d.id) }
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 6) {
            Circle().fill(statusDot).frame(width: 7, height: 7)
                .shadow(color: statusDot.opacity(0.6), radius: 3)
            Text(statusLabel)
                .font(MDFont.mono(11, weight: .bold))
                .tracking(1.8)
                .foregroundColor(statusDot)
            Spacer()
            MeshDropMark(size: 14)
        }
    }

    private var statusDot: Color {
        if isOffline { return MD.dim }
        if proxy.isStarting { return MD.flame }
        return MD.lime
    }

    private var statusLabel: String {
        if isOffline { return "OFFLINE" }
        if proxy.isStarting { return "SCAN…" }
        return "LIVE · \(devices.count)"
    }

    private var title: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(L10n.nearbyTitle)
                .font(MDFont.display(28, weight: .bold))
                .tracking(-0.6)
                .foregroundColor(MD.dpaper)
            Text(L10n.nearbyTitleSuffix)
                .font(MDFont.body(13, weight: .medium))
                .foregroundColor(MD.muted)
                .offset(y: -2)
        }
    }

    private var hint: some View {
        Text(isOffline ? L10n.nearbyHintOffline : L10n.nearbyHintCrown)
            .font(MDFont.mono(10, weight: .medium))
            .tracking(1.2)
            .foregroundColor(MD.muted)
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OFFLINE")
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text(L10n.nearbyOfflineTitle)
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text(L10n.nearbyOfflineDetail)
                .font(MDFont.body(11, weight: .regular))
                .foregroundColor(MD.muted)
            if let err = proxy.lastError {
                Text(err)
                    .font(MDFont.mono(9, weight: .regular))
                    .foregroundColor(MD.error)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.nearbyEmptyTag)
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text(L10n.nearbyEmptyTitle)
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text(L10n.nearbyEmptyDetail)
                .font(MDFont.body(11, weight: .regular))
                .foregroundColor(MD.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("↑")
                .font(MDFont.mono(12, weight: .bold))
                .foregroundColor(MD.lime)
            Text(L10n.nearbyFooterHint)
                .font(MDFont.mono(10, weight: .medium))
                .tracking(1.0)
                .foregroundColor(MD.dim)
            Spacer()
            if !selectedIDs.isEmpty {
                Text("\(selectedIDs.count)")
                    .font(MDFont.mono(11, weight: .bold))
                    .foregroundColor(MD.dink)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(MD.lime))
            }
        }
    }

    private func row(device d: WatchDeviceVM, isFocused: Bool, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Avatar(initials: d.initials, color: d.color, size: 30, ring: isFocused, ringColor: MD.lime)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(d.who)
                        .font(MDFont.display(14, weight: .semibold))
                        .foregroundColor(isFocused ? MD.dink : MD.dpaper)
                    if isSelected {
                        Text("✓")
                            .font(MDFont.mono(11, weight: .bold))
                            .foregroundColor(isFocused ? MD.dink : MD.lime)
                    }
                }
                HStack(spacing: 4) {
                    KindGlyph(kind: d.kind, size: 10)
                    Text("\(d.os) · \(d.rtt)ms")
                        .font(MDFont.mono(10, weight: .regular))
                        .foregroundColor(isFocused ? MD.dink.opacity(0.7) : MD.muted)
                }
            }
            Spacer(minLength: 0)
            Circle()
                .fill(MD.limeDeep)
                .frame(width: 6, height: 6)
                .opacity(isFocused ? 0 : 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? MD.lime : MD.dink2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? MD.lime : MD.dline, lineWidth: isFocused ? 1.5 : 0.5)
        )
    }
}

/// 发文本 sheet：watch 上用系统 TextField（点击进听写 / 涂写 / 表情）输入后发送。
private struct SendTextSheet: View {
    let peerName: String
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Text(L10n.composerTo)
                        .font(MDFont.mono(10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(MD.lime)
                    Text(peerName)
                        .font(MDFont.display(14, weight: .semibold))
                        .foregroundColor(MD.dpaper)
                        .lineLimit(1)
                }

                TextField(L10n.composerPlaceholder, text: $text)
                    .font(MDFont.body(14, weight: .regular))
                    .foregroundColor(MD.dpaper)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MD.dink2))

                Button {
                    onSend(text)
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n.composerSend)
                            .font(MDFont.mono(12, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(MD.dink)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .background(Capsule().fill(text.trimmingCharacters(in: .whitespaces).isEmpty ? MD.dim : MD.lime))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(L10n.composerCancel, role: .cancel, action: onCancel)
                    .font(MDFont.mono(10, weight: .medium))
                    .foregroundColor(MD.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(MD.dink.ignoresSafeArea())
    }
}

#Preview {
    NearbyPage(debugDevices: Mock.devices.map(WatchDeviceVM.init(mock:)))
}
