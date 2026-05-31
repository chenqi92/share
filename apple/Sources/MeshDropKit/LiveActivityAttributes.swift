//
//  LiveActivityAttributes.swift
//  MeshDropKit
//
//  传输进度 Live Activity 的 ActivityAttributes / ContentState 定义。
//
//  ⚠️ 共享类型：必须**同时**加入主 app target 和 Widget Extension target 的 membership，
//  否则 widget 端编不出同一份类型，Activity.request 的泛型对不上。
//  放在 MeshDropKit 里就是为了让两个 target 都 import 同一份。
//
//  ActivityKit 仅 iOS 16.1+ 可用。注意：ActivityKit 在 macOS 上可 import 但 ActivityAttributes
//  协议被标 @available(macOS, unavailable)，所以这里用 `#if os(iOS)` 而不是 canImport，
//  避免命令行 `swift build`（编 macOS）时报错。watchOS/tvOS/visionOS/macOS 编 MeshDropKit 时
//  自动跳过本文件，不影响其它平台。
//

#if os(iOS)
import ActivityKit
import Foundation

/// 一次文件传输的 Live Activity 属性。
///
/// - `attributes`（静态，活动期间不变）：传输方向、对端名、文件名、总字节、是否本机为发送方。
/// - `ContentState`（动态，随进度刷新）：已传字节、瞬时速率、剩余秒数、是否已结束 / 失败。
public struct MeshDropTransferActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    /// 业务层的传输 id（= ShareEngine 的 historyID 字符串）。用于 update / end 时定位活动。
    public let transferID: String
    /// 文件名。
    public let fileName: String
    /// 文件总字节。
    public let totalBytes: UInt64
    /// 对端显示名。
    public let peerName: String
    /// true = 本机在发送（上行）；false = 本机在接收（下行）。
    public let isOutgoing: Bool

    public init(transferID: String, fileName: String, totalBytes: UInt64,
                peerName: String, isOutgoing: Bool) {
        self.transferID = transferID
        self.fileName = fileName
        self.totalBytes = totalBytes
        self.peerName = peerName
        self.isOutgoing = isOutgoing
    }

    public struct State: Codable, Hashable {
        /// 已传字节。
        public var bytesDone: UInt64
        /// 瞬时速率（字节/秒），nil 表示未知。
        public var bytesPerSec: Double?
        /// 预计剩余秒数，nil 表示未知。
        public var etaSeconds: Double?
        /// 传输阶段。
        public var phase: Phase

        public init(bytesDone: UInt64, bytesPerSec: Double? = nil,
                    etaSeconds: Double? = nil, phase: Phase = .transferring) {
            self.bytesDone = bytesDone
            self.bytesPerSec = bytesPerSec
            self.etaSeconds = etaSeconds
            self.phase = phase
        }

        public enum Phase: String, Codable, Hashable {
            case transferring
            case completed
            case failed
        }
    }
}
#endif
