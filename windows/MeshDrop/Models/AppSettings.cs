using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MeshDrop.Models;

public sealed class AppSettings
{
    // ── 可见性 ──
    /// <summary>局域网可见：true=正常广告 mDNS；false=停止广告（不再被发现）。默认 true（现状）。</summary>
    [JsonPropertyName("visible_on_lan")] public bool VisibleOnLan { get; set; } = true;

    // ── 安全 ──
    /// <summary>仅显示已配对设备：true=只对信任库 fp 回 HELLO_ACK，未知 fp 直接关连接。默认 false（现状走 TOFU 配对）。</summary>
    [JsonPropertyName("trusted_only")] public bool TrustedOnly { get; set; } = false;

    // 仅用于迁移旧版的冲突开关；传输身份始终在握手阶段校验。
    [JsonPropertyName("verify_before_receive")] public bool VerifyBeforeReceive { get; set; } = true;

    /// <summary>自动接收已验证身份且保存在信任库中的设备发来的文件。</summary>
    [JsonPropertyName("auto_accept_trusted")] public bool AutoAcceptTrusted { get; set; } = true;

    [JsonPropertyName("receive_policy_version")] public int ReceivePolicyVersion { get; set; } = 1;

    // ── 剪贴板 ──
    /// <summary>跨设备剪贴板同步：门控 0x11 收/发；false=不发不收剪贴板。默认 true（现状有剪贴板收发）。</summary>
    [JsonPropertyName("clipboard_sync")] public bool ClipboardSync { get; set; } = true;

    // ── 行为 / 系统集成 ──
    /// <summary>登录时启动：注册表 Run 键开机自启。默认 false（不擅自写注册表）。</summary>
    [JsonPropertyName("launch_at_login")] public bool LaunchAtLogin { get; set; } = false;

    /// <summary>任务栏/托盘显示活跃传输数徽标。默认 true（现状 tray tooltip 已显示计数）。</summary>
    [JsonPropertyName("tray_badge")] public bool TrayBadge { get; set; } = true;

    // ────────────────────────────────────────────────────────────────────

    private static readonly JsonSerializerOptions s_options = new() { WriteIndented = true };
    private static readonly object s_gate = new();

    /// <summary>进程内单例。首次访问从磁盘 load（缺文件即默认值）。</summary>
    public static AppSettings Current { get; } = Load();

    /// <summary>任一字段保存后触发，订阅方（如 tray badge）据此刷新。</summary>
    public static event Action? Changed;

    private static string FilePath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MeshDrop",
        "settings.json");

    private static AppSettings Load()
    {
        try
        {
            var p = FilePath();
            if (!File.Exists(p)) return new AppSettings();
            return FromJson(File.ReadAllText(p));
        }
        catch
        {
            return new AppSettings();
        }
    }

    internal static AppSettings FromJson(string json)
    {
        var settings = JsonSerializer.Deserialize<AppSettings>(json, s_options) ?? new AppSettings();
        using var document = JsonDocument.Parse(json);
        if (!document.RootElement.TryGetProperty("receive_policy_version", out _))
        {
            // A manual choice with the old override disabled remains manual.
            settings.AutoAcceptTrusted = settings.VerifyBeforeReceive || settings.AutoAcceptTrusted;
            settings.ReceivePolicyVersion = 1;
        }
        return settings;
    }

    public bool ShouldAutoAccept(bool isTrusted) => isTrusted && AutoAcceptTrusted;

    /// <summary>整体覆盖写当前单例状态，并通知订阅方。best-effort，写失败不抛。</summary>
    public void Save()
    {
        lock (s_gate)
        {
            try
            {
                var p = FilePath();
                Directory.CreateDirectory(Path.GetDirectoryName(p)!);
                var data = JsonSerializer.SerializeToUtf8Bytes(this, s_options);
                var tmp = p + ".tmp";
                File.WriteAllBytes(tmp, data);
                File.Move(tmp, p, overwrite: true);
            }
            catch
            {
                // best-effort
            }
        }
        try { Changed?.Invoke(); } catch { }
    }
}
