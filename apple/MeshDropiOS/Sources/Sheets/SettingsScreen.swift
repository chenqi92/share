import SwiftUI
import UIKit
import MeshDropKit

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var engine: ShareEngine
    @State private var visible: Bool = true
    @State private var requireConfirm: Bool = true
    @State private var confirmingReset: Bool = false

    private var me: MockMe { engine.displaySelf }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader(MD("settings.section.visibility"))
                    visibilityCard
                    sectionHeader(MD("settings.section.security"))
                    securityCard
                    sectionHeader(MD("settings.section.behavior"))
                    behaviorCard
                    sectionHeader(MD("settings.section.about"))
                    aboutCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
        }
        .navigationTitle(MD("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(MD("common.done")) { dismiss() }
            }
        }
        .onChange(of: visible) { _, newValue in
            if newValue { engine.start() } else { engine.stop() }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ s: String) -> some View {
        AsciiDivider(s)
    }

    private var visibilityCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $visible) {
                row(title: MD("settings.visibility.visible.title"),
                    detail: visible ? MD("settings.visibility.visible.detail.on") : MD("settings.visibility.visible.detail.off"))
            }
            .tint(MeshDropColor.lime)
            .padding(14)
            divider
            HStack {
                row(title: MD("settings.visibility.deviceName.title"), detail: me.name)
                Spacer()
                Image(systemName: "chevron.right").opacity(0.4)
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private var securityCard: some View {
        VStack(spacing: 0) {
            HStack {
                row(title: MD("settings.security.transport.title"), detail: MD("settings.security.transport.detail"))
                Spacer()
                Chip("PLAINTEXT", tone: .flame, mono: true, uppercased: true)
            }
            .padding(14)
            divider
            HStack {
                row(title: MD("settings.security.fingerprint.title"), detail: me.fingerprint)
                Spacer()
                IconBtn("doc.on.doc", size: 28, variant: .ghost) {
                    UIPasteboard.general.string = me.fingerprint
                }
            }
            .padding(14)
            divider
            HStack {
                row(title: MD("settings.security.trust.title"), detail: MD("me.action.trust.detail", engine.trusted.count))
                Spacer()
                Image(systemName: "chevron.right").opacity(0.4)
            }
            .padding(14)
            divider
            Button {
                confirmingReset = true
            } label: {
                HStack {
                    row(title: MD("settings.security.reset.title"), detail: MD("settings.security.reset.detail"))
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(MeshDropColor.flame)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                MD("settings.security.resetConfirm.message"),
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button(MD("settings.security.reset.confirm"), role: .destructive) { engine.resetIdentity() }
                Button(MD("common.cancel"), role: .cancel) {}
            }
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private var behaviorCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $requireConfirm) {
                row(title: MD("settings.behavior.requireConfirm.title"), detail: MD("settings.behavior.requireConfirm.detail"))
            }
            .tint(MeshDropColor.lime).padding(14)
            divider
            Toggle(isOn: $engine.autoAcceptFromTrusted) {
                row(title: MD("settings.behavior.autoAccept.title"), detail: MD("settings.behavior.autoAccept.detail"))
            }
            .tint(MeshDropColor.lime).padding(14)
            divider
            Toggle(isOn: $engine.notificationsEnabled) {
                row(title: MD("settings.behavior.notifications.title"), detail: MD("settings.behavior.notifications.detail"))
            }
            .tint(MeshDropColor.lime).padding(14)
            divider
            HStack {
                row(title: MD("settings.behavior.saveTo.title"), detail: MD("settings.behavior.saveTo.detail"))
                Spacer()
                Image(systemName: "chevron.right").opacity(0.4)
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private var aboutCard: some View {
        VStack(spacing: 0) {
            HStack {
                row(title: MD("settings.about.version"), detail: "1.0.1 · build 3")
                Spacer()
            }
            .padding(14)
            divider
            HStack {
                row(title: MD("settings.about.serviceType"), detail: "_meshdrop._tcp")
                Spacer()
            }
            .padding(14)
            divider
            HStack {
                row(title: MD("settings.about.bundleId"), detail: "com.welape.landrop")
                Spacer()
            }
            .padding(14)
        }
        .background(sectionBg)
        .overlay(sectionBorder)
    }

    private func row(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(MeshDropFont.body(14.5, weight: .semibold))
            Text(detail).font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                .lineLimit(1)
        }
    }

    private var divider: some View {
        Rectangle().fill(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line)
            .frame(height: 0.5).padding(.leading, 14)
    }

    private var sectionBg: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
    }

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
    }
}
