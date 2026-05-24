import SwiftUI

/// Share Extension UI mock — 模拟系统 share sheet 拦截后的 MeshDrop 视图。
/// 本轮 UI-FIRST：实际独立 target 留待下一轮接 backend 时实装。
struct ShareExtensionMock: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var chosenDevice: String = "lily"
    @State private var includeNote: Bool = true
    @State private var encrypted: Bool = true
    @State private var expiry: String = "24 小时"

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chosenAssets
                    AsciiDivider("通过 MESHDROP 发送 · LAN")
                    deviceStrip
                    AsciiDivider("EXTRAS · 附加")
                    extras
                    Spacer(minLength: 20)
                    sendButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
        }
        .navigationTitle("MeshDrop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                MeshDropMark(size: 22)
            }
        }
    }

    private var chosenAssets: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("已选 3 张照片")
                    .font(MeshDropFont.body(14, weight: .semibold))
                Text("12.4 MB · HEIC")
                    .font(MeshDropFont.mono(11))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Photo(hue: 30 + i * 60)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var deviceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Mock.devices) { d in
                    deviceCardCompact(d, selected: chosenDevice == d.id)
                        .onTapGesture { chosenDevice = d.id }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private func deviceCardCompact(_ d: MockDevice, selected: Bool) -> some View {
        VStack(spacing: 6) {
            Avatar(initials: d.initials, color: d.color, size: 38,
                   ring: selected ? .lime : .none, online: d.isOnline)
            Text(d.who).font(MeshDropFont.body(11, weight: .semibold))
            Text(d.os).font(MeshDropFont.mono(9))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
        }
        .frame(width: 76, height: 86)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected
                      ? (scheme == .dark ? MeshDropColor.lime.opacity(0.16) : MeshDropColor.lime.opacity(0.32))
                      : (scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? MeshDropColor.lime : (scheme == .dark ? MeshDropColor.dline : MeshDropColor.line),
                              lineWidth: selected ? 1 : 0.5)
        )
    }

    private var extras: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $includeNote) {
                HStack {
                    Image(systemName: "note.text").frame(width: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("加文字便签").font(MeshDropFont.body(13.5, weight: .semibold))
                        Text("随手记一句").font(MeshDropFont.mono(10))
                            .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                    }
                }
            }
            .tint(MeshDropColor.lime)
            .padding(14)
            divider
            Toggle(isOn: $encrypted) {
                HStack {
                    Image(systemName: "lock.shield").frame(width: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("端对端加密").font(MeshDropFont.body(13.5, weight: .semibold))
                        Text("默认开启").font(MeshDropFont.mono(10))
                            .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                    }
                }
            }
            .tint(MeshDropColor.lime)
            .padding(14)
            divider
            HStack {
                Image(systemName: "clock").frame(width: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text("过期时间").font(MeshDropFont.body(13.5, weight: .semibold))
                    Text("超时未取消接收则自动撤回").font(MeshDropFont.mono(10))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                }
                Spacer()
                Text(expiry).font(MeshDropFont.mono(11, weight: .medium))
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var divider: some View {
        Rectangle().fill(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line)
            .frame(height: 0.5).padding(.leading, 50)
    }

    private var target: MockDevice {
        Mock.devices.first(where: { $0.id == chosenDevice }) ?? Mock.devices[0]
    }

    private var sendButton: some View {
        Button { dismiss() } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
                Text("发送给 \(target.who)")
                    .font(MeshDropFont.body(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(MeshDropColor.lime))
            .foregroundStyle(MeshDropColor.ink)
        }
        .buttonStyle(.plain)
    }
}
