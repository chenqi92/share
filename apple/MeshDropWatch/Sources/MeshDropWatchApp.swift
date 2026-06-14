import SwiftUI

@main
struct MeshDropWatchApp: App {
    @StateObject private var engine = WatchEngineProxy.shared

    var body: some Scene {
        WindowGroup {
            RootView(initialTab: Self.initialTabFromArgs())
                .environmentObject(engine)
                .onAppear { engine.start() }
        }
    }

    /// 支持启动参数 `--page <0|1|2|3>` 用于截图脚本切到指定页
    private static func initialTabFromArgs() -> Int {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--page"), idx + 1 < args.count,
           let v = Int(args[idx + 1]) {
            return max(0, min(3, v))
        }
        if let envPage = ProcessInfo.processInfo.environment["MESHDROP_PAGE"],
           let v = Int(envPage) {
            return max(0, min(3, v))
        }
        return 0
    }
}

/// 顶层 TabView：垂直翻页（Apple Watch 推荐模式，配合表冠）
struct RootView: View {
    @State private var selection: Int

    init(initialTab: Int) {
        // 初始 tab 只在视图首次构造时定一次，避免 onAppear 在视图重建时把用户弹回首屏。
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            NearbyPage()
                .tag(0)
                .containerBackground(MD.dink, for: .tabView)
            ReceivePage()
                .tag(1)
                .containerBackground(MD.dink, for: .tabView)
            TransferPage()
                .tag(2)
                .containerBackground(MD.dink, for: .tabView)
            ComplicationPreviewView()
                .tag(3)
                .containerBackground(MD.dink, for: .tabView)
        }
        .tabViewStyle(.verticalPage)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView(initialTab: 0)
}
