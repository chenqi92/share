using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace MeshDrop.Mock;

public enum MockKind { Mac, Win, Ipad, Ios, Android, Linux }

public enum MockTransferState
{
    Queued,
    Sending,
    Receiving,
    Done,
    Failed,
}

public enum MockHistoryKind { Text, File, Image }
public enum MockClipboardKind { Text, Link, Code }

public sealed record MockDevice(
    string Id,
    string Name,
    string Who,
    MockKind Kind,
    double Dist,           // 0..1
    int Angle,             // 0..359
    string ColorHex,
    string Initials,
    string Os,
    int Rtt,
    string Fingerprint = "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
    string Ip = "192.168.1.31",
    string Bw = "940 Mbps",
    bool E2EVerified = true);

public sealed record MockHistory(
    string Id,
    string Dir,               // "incoming" | "outgoing"
    string Peer,
    string Time,
    MockHistoryKind Kind,
    string? Name = null,
    string? Size = null,
    string? Ext = null,
    string? Content = null,
    int? Count = null,
    int? Progress = null,
    string Status = "done")
{
    public string DirArrow => Dir == "outgoing" ? "↑" : "↓";

    public string KindLabel => Kind switch
    {
        MockHistoryKind.Text => "TEXT",
        MockHistoryKind.File => Ext is null ? "FILE" : $"FILE · {Ext.ToUpperInvariant()}",
        MockHistoryKind.Image => Count is int n ? $"IMAGE · {n} 张" : "IMAGE",
        _ => "TEXT",
    };

    public string Summary => Kind switch
    {
        MockHistoryKind.Text => Content ?? "",
        MockHistoryKind.File => $"{Name ?? "(unknown)"}  ·  {Size ?? ""}",
        MockHistoryKind.Image => Count is int n ? $"{n} 张图片" : "图片",
        _ => "",
    };

    public string StatusLabel => Status switch
    {
        "done" => "DONE",
        "transferring" => Progress is int p ? $"{p}%" : "活跃",
        "queued" => "QUEUED",
        "failed" => "FAILED",
        _ => Status.ToUpperInvariant(),
    };

    public ChipToneName StatusTone => Status switch
    {
        "done" => ChipToneName.Lime,
        "transferring" => Dir == "outgoing" ? ChipToneName.Flame : ChipToneName.Sky,
        "failed" => ChipToneName.Error,
        _ => ChipToneName.Outline,
    };
}

/// <summary>独立 chip tone 名（避免直接引 Views.Controls 命名空间，免 mock 依赖 UI）。</summary>
public enum ChipToneName { Mute, Lime, Ink, Outline, Flame, Sky, Error }

public sealed record MockPendingPairing(
    string Id,
    string Peer,
    string DeviceName,
    string Fingerprint,
    string ReceivedAt);

public sealed record MockPendingOffer(
    string Id,
    string Peer,
    string DeviceName,
    string FileName,
    string FileSize,
    string Note,
    string ReceivedAt);

public sealed record MockClipboard(
    string Id,
    string Who,
    MockClipboardKind Kind,
    string Body,
    string Ago,
    string? Lang = null)
{
    public string KindLabel => Kind switch
    {
        MockClipboardKind.Text => "TEXT",
        MockClipboardKind.Link => "LINK",
        MockClipboardKind.Code => Lang is null ? "CODE" : $"CODE · {Lang.ToUpperInvariant()}",
        _ => "TEXT",
    };
}

public sealed record MockTransfer(
    string Name,
    string Size,
    string Ext,
    string From,
    string To,
    int Progress,
    MockTransferState State,
    string? Speed = null,
    string Eta = "")
{
    public string FromToText => $"{From} → {To}";
}

public sealed record MockMessage(
    string Id,
    string Side,              // "in" | "out"
    string Kind,              // "text" | "file" | "image"
    string? Text = null,
    string? Time = null,
    bool Delivered = true,
    string? FileName = null,
    string? FileSize = null,
    string? FileExt = null);

public sealed record MockMe(
    string Name = "DEV-01 · Win 11",
    string Fingerprint = "ZX8K · L72M · 9FQ3 · 7HD2",
    string Ip = "192.168.1.42",
    string Os = "Win 11",
    string Visibility = "可见",
    string Lan = "ACME-LAN");

public sealed record MockTrust(
    string Who,
    string DeviceName,
    string Os,
    string Fingerprint,
    string PairedOn,
    string LastSeen,
    bool RememberAllowed);

/// <summary>
/// COMMON §9 设计语言数据样本 —— 仅供 XAML designer preview 和单元测试用。
/// runtime 一律走 ShareEngine + EngineProjection，不要在 release path 引用本类。
/// </summary>
#if DEBUG
public static class MockData
{
    public static readonly MockMe Me = new();

    public static readonly IReadOnlyList<MockDevice> Devices = new[]
    {
        new MockDevice("lily",   "Lily's MacBook",   "李莉",   MockKind.Mac,     0.55, 35,  "#FFB4A1", "LL", "macOS 15.3", 18,
            Ip:"192.168.1.31", Bw:"940 Mbps (LAN)", Fingerprint:"ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF"),
        new MockDevice("kun",    "Kun · Pixel 8",    "坤",     MockKind.Android, 0.78, 110, "#B7E5C8", "K",  "Pixel · Android 15", 32,
            Ip:"192.168.1.37", Bw:"540 Mbps", Fingerprint:"V2KN · 4HD8 · QX91 · LM3F · NP7B · K8RZ · F4WX · 2GLM"),
        new MockDevice("jiawei", "Jiawei · iPad",    "嘉伟",   MockKind.Ipad,    0.40, 200, "#C7B8FF", "JW", "iPadOS 18.2", 14,
            Ip:"192.168.1.44", Bw:"866 Mbps", Fingerprint:"BFM8 · 7KQ2 · X3LN · 9PRD · ZM4F · K8H1 · NQ6W · L2VR"),
        new MockDevice("mengxi", "Meng Xi · iPhone", "孟茜",   MockKind.Ios,     0.62, 265, "#FFD970", "MX", "iOS 18.2", 26,
            Ip:"192.168.1.49", Bw:"700 Mbps", Fingerprint:"H7LZ · 2K9F · QM48 · X1DR · NB5P · FW3K · L8VQ · ZR62"),
        new MockDevice("dev01",  "DEV-01 · Win 11",  "工位机", MockKind.Win,     0.88, 320, "#9AD0FF", "D1", "Windows 11", 41,
            Ip:"192.168.1.42", Bw:"940 Mbps", Fingerprint:"ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF"),
    };

    public static readonly IReadOnlyList<MockHistory> History = new[]
    {
        new MockHistory("h6", "incoming", "孟茜", "14:18", MockHistoryKind.Image, Count: 2, Status: "done"),
        new MockHistory("h5", "outgoing", "孟茜", "14:10", MockHistoryKind.File, Name: "设计稿_v3_final.fig", Size: "14.2 MB", Ext: "fig", Status: "done"),
        new MockHistory("h4", "outgoing", "李莉", "14:09", MockHistoryKind.Text, Content: "改完了，整理一下发你 ", Status: "done"),
        new MockHistory("h3", "outgoing", "嘉伟", "14:08", MockHistoryKind.File, Name: "iOS-mocks-final.zip", Size: "48.6 MB", Ext: "zip", Progress: 67, Status: "transferring"),
        new MockHistory("h2", "incoming", "坤",   "13:58", MockHistoryKind.File, Name: "IMG_4821~38.heic",    Size: "128 MB",  Ext: "heic", Progress: 12, Status: "transferring"),
        new MockHistory("h1", "outgoing", "李莉", "13:42", MockHistoryKind.File, Name: "demo-video.mp4",      Size: "512 MB",  Ext: "mp4", Status: "queued"),
    };

    public static readonly MockPendingPairing PendingPairing = new(
        "pp-1", "李莉", "Lily's MacBook",
        "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        "8s ago");

    public static readonly MockPendingOffer PendingOffer = new(
        "po-1", "嘉伟", "Jiawei · iPad",
        "规划文档_v0.3.pages", "3.4 MB",
        "改完了帮我看下第二章，特别是 §2.3 那段",
        "just now");

    public static readonly IReadOnlyList<MockClipboard> Clipboard = new[]
    {
        new MockClipboard("cb1", "嘉伟", MockClipboardKind.Link, "https://internal.acme.io/specs/auth-v3", "8s"),
        new MockClipboard("cb2", "孟茜", MockClipboardKind.Text, "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配", "12m"),
        new MockClipboard("cb3", "李莉", MockClipboardKind.Code, "docker run --rm -v $PWD:/app meshdrop/build:latest", "34m", Lang:"sh"),
        new MockClipboard("cb4", "坤",   MockClipboardKind.Text, "会议室 B 已订到 16:00–17:30", "1h"),
        new MockClipboard("cb5", "我",   MockClipboardKind.Link, "figma://file/Q8xK2/MeshDrop?node-id=42:108", "2h"),
    };

    public static readonly IReadOnlyList<MockTransfer> Transfers = new[]
    {
        new MockTransfer("设计稿_v3_final.fig",  "14.2 MB",        "fig",  "我",   "孟茜",   100, MockTransferState.Done,                   Eta:"00:08"),
        new MockTransfer("iOS-mocks-final.zip",   "48.6 MB",        "zip",  "我",   "孟茜",   67,  MockTransferState.Sending,   "8.4 MB/s",   Eta:"00:02"),
        new MockTransfer("spec_PRD_2026Q1.pdf",   "2.1 MB",         "pdf",  "我",   "嘉伟",   34,  MockTransferState.Sending,   "3.1 MB/s",   Eta:"00:01"),
        new MockTransfer("IMG_4821~IMG_4838.heic","128 MB · 18 张", "heic", "坤",   "我",     12,  MockTransferState.Receiving, "11.7 MB/s",  Eta:"00:09"),
        new MockTransfer("release-notes.md",      "4.8 KB",         "md",   "我",   "DEV-01", 100, MockTransferState.Done,                   Eta:"00:01"),
        new MockTransfer("demo-video.mp4",        "512 MB",         "mp4",  "我",   "李莉",   0,   MockTransferState.Queued),
    };

    public static readonly int[] UploadBars   = { 3, 5, 8, 7, 9, 6, 11, 12, 14, 11, 10, 11, 12, 11 };
    public static readonly int[] DownloadBars = { 8, 9, 7, 6, 5, 7, 10, 12, 11, 12, 11, 12, 11, 12 };
    public static readonly int[] SessionBars  = { 2, 3, 5, 4, 6, 8, 7, 9, 10, 12, 11, 12, 11, 12, 14 };

    /// <summary>聊天页 mock 消息流（与李莉）。</summary>
    public static readonly IReadOnlyList<MockMessage> ChatWithLily = new[]
    {
        new MockMessage("m1", "in",  "text",  Text:"周末雷达扫描的卡顿排查得怎样？",                       Time:"13:32"),
        new MockMessage("m2", "out", "text",  Text:"找到了，mDNS QueryService 每 800ms 触发一次，改成 2.4s 之后稳定。", Time:"13:33"),
        new MockMessage("m3", "in",  "text",  Text:"赞 那这块就 freeze 了？",                                 Time:"13:33"),
        new MockMessage("m4", "out", "text",  Text:"是的。我把改后的对比图发你",                              Time:"13:34"),
        new MockMessage("m5", "out", "file",  FileName:"radar-diff.png",   FileSize:"384 KB",  FileExt:"png", Time:"13:35"),
        new MockMessage("m6", "in",  "text",  Text:"看了，比之前清爽多了。要不要顺便把 sweep 周期调成 4.5s？", Time:"13:38"),
        new MockMessage("m7", "out", "text",  Text:"已经是 4.5s 了 ",                                         Time:"13:39"),
        new MockMessage("m8", "out", "file",  FileName:"设计稿_v3_final.fig", FileSize:"14.2 MB", FileExt:"fig", Time:"14:10"),
    };

    public static readonly IReadOnlyList<MockTrust> Trusted = new[]
    {
        new MockTrust("李莉", "Lily's MacBook",   "macOS 15.3",   "ZX8K · L72M · 9FQ3 · 7HD2", "2026-04-21", "刚刚", true),
        new MockTrust("嘉伟", "Jiawei · iPad",    "iPadOS 18.2",  "BFM8 · 7KQ2 · X3LN · 9PRD", "2026-04-18", "14:08", true),
        new MockTrust("孟茜", "Meng Xi · iPhone", "iOS 18.2",     "H7LZ · 2K9F · QM48 · X1DR", "2026-03-09", "14:10", true),
        new MockTrust("坤",   "Kun · Pixel 8",    "Android 15",   "V2KN · 4HD8 · QX91 · LM3F", "2026-02-26", "13:58", true),
    };
}

/// <summary>给 XAML ItemsControl 用的可观察集合工厂（仅 designer preview 用）。</summary>
public static class MockObs
{
    public static ObservableCollection<MockDevice> Devices() => new(MockData.Devices);
    public static ObservableCollection<MockHistory> History() => new(MockData.History);
    public static ObservableCollection<MockClipboard> Clipboard() => new(MockData.Clipboard);
    public static ObservableCollection<MockTransfer> Transfers() => new(MockData.Transfers);
    public static ObservableCollection<MockMessage> ChatWithLily() => new(MockData.ChatWithLily);
    public static ObservableCollection<MockTrust> Trusted() => new(MockData.Trusted);
}
#endif
