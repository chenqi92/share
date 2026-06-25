using Microsoft.Windows.ApplicationModel.Resources;

namespace MeshDrop;

/// <summary>
/// 代码侧 i18n 取串入口。XAML 标准控件属性走 x:Uid，自定义控件属性 / VM 动态文案走这里。
/// 为什么集中封装：ResourceLoader 实例创建有开销且需 view-independent（后台线程也会取串，
/// 如 ToastService 在引擎事件回调里构造通知），用单例 view-independent loader 一次性持有。
/// key 用点分命名空间（与各平台对照），内部转成 resw 的斜杠分段（resw 名里不能带点，
/// 点会被当成属性限定符）。
/// </summary>
public static class I18n
{
    // 默认 ResourceLoader：从 resources.pri 的 Resources 子树取串（即两份 Resources.resw）。
    // WinAppSDK 的这一 ResourceLoader 适配 unpackaged 且不绑定具体视图，可在任意线程取串
    // （ToastService 在引擎事件回调线程构造通知文案需要这点）。
    private static readonly ResourceLoader Loader = new();

    // 与 x:Uid 对齐的属性后缀：这些是 resw name 里点分的「属性限定符」，不能转成斜杠。
    // 其余点都是命名空间分隔符 → 转成斜杠（resw name 不能含点的命名空间段）。
    private static readonly string[] PropSuffixes =
        { ".Text", ".Header", ".Content", ".PlaceholderText", ".OnContent", ".OffContent" };

    /// <summary>按点分 key 取本地化串；缺失时回退 key 本身，便于静态核对暴露遗漏。</summary>
    public static string T(string key)
    {
        // 拆出可能的属性后缀（如 .Text），剩余命名空间段把点换成斜杠，再拼回后缀。
        var suffix = "";
        foreach (var p in PropSuffixes)
        {
            if (key.EndsWith(p, System.StringComparison.Ordinal))
            {
                suffix = p;
                key = key.Substring(0, key.Length - p.Length);
                break;
            }
        }
        var name = key.Replace('.', '/') + suffix;
        try
        {
            var s = Loader.GetString(name);
            return string.IsNullOrEmpty(s) ? name : s;
        }
        catch
        {
            // WinAppSDK 的 ResourceLoader.GetString 在 key 缺失时会抛 COMException(0x80073B17)，
            // 而非返回空串；这里吞掉并回退 name，避免任一缺失文案直接崩掉整个应用。
            return name;
        }
    }

    /// <summary>带占位符的格式化串（resw 里用 {0}/{1}…）。</summary>
    public static string T(string key, params object[] args) =>
        string.Format(T(key), args);
}
