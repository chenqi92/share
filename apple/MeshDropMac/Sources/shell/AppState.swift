import SwiftUI
import Combine

/// 主区路由 + 选中设备 + 选项卡 …… 整个 app 状态。本轮全部 mock。
enum MainTab: String, CaseIterable, Identifiable {
    case discovery, chat, transfers, history, clipboard, trust, settings
    case pairing, onboarding, receive, menubar, dragdrop
    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    @Published var tab: MainTab = .discovery
    @Published var selectedDeviceID: String = MockDevice.all[3].id   // 默认孟茜
    @Published var searchQuery: String = ""
    @Published var displayName: String = MockMe.deviceName
    @Published var transferFilter: TransferState? = nil
    @Published var showDragOverlay: Bool = false
    @Published var dragFileSummary: String = "3 个文件 · 78.2 MB → 孟茜"

    var selectedDevice: MockDevice {
        MockDevice.all.first(where: { $0.id == selectedDeviceID }) ?? MockDevice.all[0]
    }
}
