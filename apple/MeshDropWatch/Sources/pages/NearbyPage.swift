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
        .alert(alertText, isPresented: $alertShown) { Button("好", role: .cancel) {} }
    }

    private func handleTap(idx: Int, device d: WatchDeviceVM) {
        guard !isOffline else { return }
        focusIndex = idx
        if selectedIDs.isEmpty {
            alertText = "已选 · \(d.who)"
        } else {
            if selectedIDs.contains(d.id) { selectedIDs.remove(d.id) } else { selectedIDs.insert(d.id) }
            alertText = "多选 · \(selectedIDs.count) 台"
        }
        WKInterfaceDevice.current().play(.click)
        alertShown = true
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
            Text("附近")
                .font(MDFont.display(28, weight: .bold))
                .tracking(-0.6)
                .foregroundColor(MD.dpaper)
            Text("· Nearby")
                .font(MDFont.body(13, weight: .medium))
                .foregroundColor(MD.muted)
                .offset(y: -2)
        }
    }

    private var hint: some View {
        Text(isOffline ? "iPhone 不在身边 · OFFLINE" : "转动表冠选人 · CROWN TO PICK")
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
            Text("iPhone 不在身边")
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text("等手机靠近自动回连")
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
            Text("空 · EMPTY")
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text("附近没有设备")
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text("让朋友也打开 MeshDrop")
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
            Text("点击发送 · 长按多选")
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

#Preview {
    NearbyPage(debugDevices: Mock.devices.map(WatchDeviceVM.init(mock:)))
}
