import Foundation
import Combine
import MeshDropKit
import OSLog

#if canImport(ActivityKit)
import ActivityKit
#endif

private let log = Logger(subsystem: "com.welape.meshdrop", category: "LiveActivity")

/// 传输进度 Live Activity 的生命周期管理器。
///
/// 订阅 [ShareEngine] 的 `$history` + `$transferMetrics`：
/// - 出现新的 `.transferring` 文件项 → `Activity.request(...)` 起活动
/// - 进度 / 速率变化 → `activity.update(...)`（节流 ≥0.5s）
/// - 进入 `.completed` / `.failed` / `.canceled` → `activity.end(...)`
///
/// 需要用户在 Xcode 配置（见文件 LiveActivityREADME 注释 / 返回说明）：
/// - 主 app Info.plist 加 `NSSupportsLiveActivities = YES`
/// - 新建 Widget Extension target，把 MeshDropTransferActivityAttributes 共享给它
///
/// ActivityKit 不可用（< iOS 16.1 或非 iOS）时，本类所有方法 no-op，不影响其它功能。
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var subs: Set<AnyCancellable> = []
    private var lastUpdateAt: [String: Date] = [:]
    private var attached = false

    #if canImport(ActivityKit)
    /// transferID(historyID) → 进行中的 Activity。
    private var activities: [String: Activity<MeshDropTransferActivityAttributes>] = [:]
    #endif

    private init() {}

    /// 接到 engine：订阅历史变化驱动 Live Activity。主 app 启动时调一次。
    func attach(to engine: ShareEngine) {
        guard !attached else { return }
        attached = true

        engine.$history
            .sink { [weak self, weak engine] items in
                guard let self, let engine else { return }
                self.reconcile(items: items, engine: engine)
            }
            .store(in: &subs)
    }

    /// 用最新 history 快照对齐活动集合。
    private func reconcile(items: [HistoryItem], engine: ShareEngine) {
        for item in items {
            guard case .file(let name, let size, _) = item.kind else { continue }
            switch item.status {
            case .transferring(let done, let total):
                let metric = engine.transferMetrics[item.id]
                if hasActivity(for: item.id.uuidString) {
                    updateActivity(
                        id: item.id.uuidString,
                        bytesDone: done,
                        bytesPerSec: metric?.bytesPerSec,
                        eta: metric?.etaSeconds,
                        phase: .transferring
                    )
                } else {
                    startActivity(
                        id: item.id.uuidString,
                        fileName: name,
                        totalBytes: total == 0 ? size : total,
                        peerName: item.peer.name,
                        isOutgoing: item.direction == .outgoing,
                        bytesDone: done
                    )
                }
            case .completed:
                endActivity(id: item.id.uuidString, phase: .completed, finalBytes: size)
            case .failed:
                endActivity(id: item.id.uuidString, phase: .failed, finalBytes: nil)
            case .canceled:
                endActivity(id: item.id.uuidString, phase: .failed, finalBytes: nil)
            default:
                break
            }
        }
    }

    // MARK: - ActivityKit 包装

    private func hasActivity(for id: String) -> Bool {
        #if canImport(ActivityKit)
        return activities[id] != nil
        #else
        return false
        #endif
    }

    func startActivity(id: String, fileName: String, totalBytes: UInt64,
                       peerName: String, isOutgoing: Bool, bytesDone: UInt64) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("Live Activities 未授权，跳过 start")
            return
        }
        guard activities[id] == nil else { return }
        let attributes = MeshDropTransferActivityAttributes(
            transferID: id, fileName: fileName, totalBytes: totalBytes,
            peerName: peerName, isOutgoing: isOutgoing
        )
        let initial = MeshDropTransferActivityAttributes.ContentState(
            bytesDone: bytesDone, phase: .transferring
        )
        do {
            let activity: Activity<MeshDropTransferActivityAttributes>
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initial, staleDate: nil)
                )
            } else {
                activity = try Activity.request(attributes: attributes, contentState: initial)
            }
            activities[id] = activity
            log.info("Live Activity 起动 id=\(id, privacy: .public)")
        } catch {
            log.error("Activity.request 失败：\(error.localizedDescription)")
        }
        #endif
    }

    func updateActivity(id: String, bytesDone: UInt64, bytesPerSec: Double?,
                        eta: Double?, phase: MeshDropTransferActivityAttributes.ContentState.Phase) {
        #if canImport(ActivityKit)
        guard let activity = activities[id] else { return }
        // 节流 ≥ 0.5s，避免 chunk 频率刷爆系统更新限额。
        let now = Date()
        if let last = lastUpdateAt[id], now.timeIntervalSince(last) < 0.5, phase == .transferring {
            return
        }
        lastUpdateAt[id] = now
        let state = MeshDropTransferActivityAttributes.ContentState(
            bytesDone: bytesDone, bytesPerSec: bytesPerSec, etaSeconds: eta, phase: phase
        )
        Task {
            if #available(iOS 16.2, *) {
                await activity.update(.init(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
        #endif
    }

    func endActivity(id: String, phase: MeshDropTransferActivityAttributes.ContentState.Phase,
                     finalBytes: UInt64?) {
        #if canImport(ActivityKit)
        guard let activity = activities.removeValue(forKey: id) else { return }
        lastUpdateAt[id] = nil
        let finalState = MeshDropTransferActivityAttributes.ContentState(
            bytesDone: finalBytes ?? 0, phase: phase
        )
        Task {
            if #available(iOS 16.2, *) {
                // 完成后锁屏再保留几秒，让用户看到结果。
                await activity.end(.init(state: finalState, staleDate: nil),
                                   dismissalPolicy: .after(.now + 4))
            } else {
                await activity.end(using: finalState, dismissalPolicy: .after(.now + 4))
            }
        }
        log.info("Live Activity 结束 id=\(id, privacy: .public) phase=\(phase.rawValue, privacy: .public)")
        #endif
    }
}
