namespace MeshDrop.Models;

public enum DeviceOS
{
    Ios, Android, Macos, Windows, Linux
}

public static class DeviceOSExtensions
{
    public static string ToRaw(this DeviceOS os) => os switch
    {
        DeviceOS.Ios => "ios",
        DeviceOS.Android => "android",
        DeviceOS.Macos => "macos",
        DeviceOS.Windows => "windows",
        DeviceOS.Linux => "linux",
        _ => "linux",
    };

    public static DeviceOS? Parse(string s) => s switch
    {
        "ios" => DeviceOS.Ios,
        "android" => DeviceOS.Android,
        "macos" => DeviceOS.Macos,
        "windows" => DeviceOS.Windows,
        "linux" => DeviceOS.Linux,
        _ => null,
    };
}

/// <summary>
/// 协议规范定义的设备元数据。等价于 Swift `Device`、Kotlin `Device`。
/// </summary>
public sealed record Device(
    string Id,            // 32 hex
    string Name,          // 已 base64url 解码
    DeviceOS Os,
    string? Model,
    string Fingerprint,   // 32 hex
    ushort Port,
    byte ProtocolVersion = 1
)
{
    /// <summary>4 字符分组、空格分隔、大写。</summary>
    public string HumanFingerprint
    {
        get
        {
            var upper = Fingerprint.ToUpperInvariant();
            var groups = new System.Collections.Generic.List<string>();
            for (var i = 0; i < upper.Length; i += 4)
                groups.Add(upper.Substring(i, System.Math.Min(4, upper.Length - i)));
            return string.Join(' ', groups);
        }
    }
}

/// <summary>给 XAML DataTemplate 用的 ViewModel 投影。</summary>
public sealed record DeviceVM(string Id, string Name, string Subtitle, string IconGlyph)
{
    public static DeviceVM From(Device d) => new(
        Id: d.Id,
        Name: d.Name,
        Subtitle: d.Model is null ? d.Os.ToRaw() : $"{d.Os.ToRaw()} · {d.Model}",
        IconGlyph: d.Os switch
        {
            DeviceOS.Ios => "",        // PhoneBook
            DeviceOS.Android => "",
            DeviceOS.Macos => "",      // Tablet/laptop
            DeviceOS.Windows => "",    // Devices
            DeviceOS.Linux => "",
            _ => "",
        });
}
