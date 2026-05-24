#!/usr/bin/env swift
// MeshDrop 图标批生成。一次性运行，把 source-light.png 烤成 5 端所有需要的尺寸/形状。
//
// 用法：
//   swift tools/iconforge.swift
//
// 不依赖第三方库，仅 AppKit / CoreGraphics。

import AppKit
import Foundation

let projectRoot = FileManager.default.currentDirectoryPath
let sourceLight = "\(projectRoot)/tools/source-light.png"

struct Job {
    let output: String
    let size: Int
    /// 圆角半径 / 短边。0 = 不裁剪；0.22 ≈ Apple squircle；0.5 = 圆形。
    let radiusRatio: Double
    /// 内容缩放因子。1.0 = 填满；< 1.0 = 周围留 padding（Android adaptive 必需）。
    let innerScale: Double
    /// 背景填色。nil = 透明。
    let backgroundColor: NSColor?
}

let jobs: [Job] = [
    // ─── iOS：1024 单图，iOS 自动 squircle mask；保留原图所有内容 ─────────────
    Job(output: "apple/ShareiOS/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        size: 1024, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),

    // ─── macOS：传统多 size。Apple 文档要求 16/32/128/256/512 @1x+@2x 全套 ──
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-16.png",
        size: 16, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-32.png",
        size: 32, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-64.png",
        size: 64, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-128.png",
        size: 128, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-256.png",
        size: 256, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-512.png",
        size: 512, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),
    Job(output: "apple/ShareMac/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        size: 1024, radiusRatio: 0, innerScale: 1.0, backgroundColor: nil),

    // ─── Android legacy mipmap (square 圆角 + round) ─────────────────────────
    // square 圆角 22% ≈ Material 推荐
    Job(output: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png",
        size: 48, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-hdpi/ic_launcher.png",
        size: 72, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",
        size: 96, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",
        size: 144, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
        size: 192, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    // round = 圆形
    Job(output: "android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png",
        size: 48, radiusRatio: 0.5, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png",
        size: 72, radiusRatio: 0.5, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png",
        size: 96, radiusRatio: 0.5, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png",
        size: 144, radiusRatio: 0.5, innerScale: 1.0, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png",
        size: 192, radiusRatio: 0.5, innerScale: 1.0, backgroundColor: nil),

    // ─── Android adaptive icon foreground (108dp，中心 72dp 是可见 viewport) ─
    // foreground 内容必须缩到 72/108 ≈ 0.66 才能完整可见
    Job(output: "android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png",
        size: 108, radiusRatio: 0, innerScale: 0.66, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png",
        size: 162, radiusRatio: 0, innerScale: 0.66, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png",
        size: 216, radiusRatio: 0, innerScale: 0.66, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png",
        size: 324, radiusRatio: 0, innerScale: 0.66, backgroundColor: nil),
    Job(output: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png",
        size: 432, radiusRatio: 0, innerScale: 0.66, backgroundColor: nil),

    // ─── Windows：256 圆角（用户明确要求方形不好看）────────────────────────
    Job(output: "windows/ShareWindows/Assets/AppIcon.png",
        size: 256, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    // 多分辨率 PNG，供 .ico 生成或多 size 资源
    Job(output: "windows/ShareWindows/Assets/AppIcon-48.png",
        size: 48, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "windows/ShareWindows/Assets/AppIcon-128.png",
        size: 128, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),

    // ─── Linux：标准位置 + 多分辨率（hicolor theme 规范）────────────────────
    Job(output: "linux/data/icons/hicolor/48x48/apps/drop.mesh.linux.png",
        size: 48, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "linux/data/icons/hicolor/64x64/apps/drop.mesh.linux.png",
        size: 64, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "linux/data/icons/hicolor/128x128/apps/drop.mesh.linux.png",
        size: 128, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "linux/data/icons/hicolor/256x256/apps/drop.mesh.linux.png",
        size: 256, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
    Job(output: "linux/data/icons/hicolor/512x512/apps/drop.mesh.linux.png",
        size: 512, radiusRatio: 0.22, innerScale: 1.0, backgroundColor: nil),
]

func render(_ job: Job) throws {
    guard let src = NSImage(contentsOfFile: sourceLight) else {
        FileHandle.standardError.write(Data("cannot load source: \(sourceLight)\n".utf8))
        exit(1)
    }
    let outDir = (job.output as NSString).deletingLastPathComponent
    try FileManager.default.createDirectory(
        atPath: outDir, withIntermediateDirectories: true)

    let size = job.size
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    ) else {
        throw NSError(domain: "iconforge", code: 1, userInfo: [NSLocalizedDescriptionKey: "alloc bitmap"])
    }
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    if job.radiusRatio > 0 {
        let r = CGFloat(Double(size) * job.radiusRatio)
        NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).addClip()
    }

    if let bg = job.backgroundColor {
        bg.setFill()
        rect.fill()
    }

    let inner = CGFloat(job.innerScale) * CGFloat(size)
    let padding = (CGFloat(size) - inner) / 2
    let drawRect = NSRect(x: padding, y: padding, width: inner, height: inner)
    src.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "iconforge", code: 2, userInfo: [NSLocalizedDescriptionKey: "encode png"])
    }
    try data.write(to: URL(fileURLWithPath: job.output))
    print("✓ \(String(format: "%4d", job.size))px  \(job.output)")
}

print("source: \(sourceLight)")
print("jobs: \(jobs.count)")
print()

for j in jobs {
    do { try render(j) }
    catch { print("✗ \(j.output): \(error)") }
}

// ─── ICO 打包：把多分辨率 PNG 塞进一个 .ico (PNG-embedded, Vista+) ─────────
struct IcoEntry {
    let path: String
    let size: Int
}

func packICO(entries: [IcoEntry], output: String) throws {
    // ICO 文件结构：
    //   ICONDIR (6 字节) + N × ICONDIRENTRY (16 字节) + N 段 PNG 数据
    var header = Data()
    header.append(le16(0))                 // reserved
    header.append(le16(1))                 // type = icon
    header.append(le16(UInt16(entries.count)))

    let headerSize = 6 + 16 * entries.count
    var currentOffset = UInt32(headerSize)
    var directory = Data()
    var blob = Data()

    for e in entries {
        let pngData = try Data(contentsOf: URL(fileURLWithPath: e.path))
        let sizeByte: UInt8 = e.size >= 256 ? 0 : UInt8(e.size)

        directory.append(sizeByte)         // width
        directory.append(sizeByte)         // height
        directory.append(0)                // color palette count
        directory.append(0)                // reserved
        directory.append(le16(1))          // color planes
        directory.append(le16(32))         // bits per pixel
        directory.append(le32(UInt32(pngData.count)))
        directory.append(le32(currentOffset))

        blob.append(pngData)
        currentOffset += UInt32(pngData.count)
    }

    var ico = Data()
    ico.append(header)
    ico.append(directory)
    ico.append(blob)

    try FileManager.default.createDirectory(
        atPath: (output as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true)
    try ico.write(to: URL(fileURLWithPath: output))
    print("✓ ICO    \(output)  (\(entries.count) sizes, \(ico.count) bytes)")
}

func le16(_ v: UInt16) -> Data {
    var x = v.littleEndian
    return Data(bytes: &x, count: 2)
}
func le32(_ v: UInt32) -> Data {
    var x = v.littleEndian
    return Data(bytes: &x, count: 4)
}

do {
    try packICO(
        entries: [
            IcoEntry(path: "windows/ShareWindows/Assets/AppIcon-48.png",  size: 48),
            IcoEntry(path: "windows/ShareWindows/Assets/AppIcon-128.png", size: 128),
            IcoEntry(path: "windows/ShareWindows/Assets/AppIcon.png",     size: 256),
        ],
        output: "windows/ShareWindows/Assets/AppIcon.ico"
    )
} catch {
    print("✗ ICO pack failed: \(error)")
}

print("\ndone.")
