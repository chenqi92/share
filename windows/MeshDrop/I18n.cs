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
    // MRT Core：直接用 MainResourceMap 取串。ResourceLoader.GetString 在 unpackaged 下定位
    // "Resources" 子树不稳（缺失会抛 COMException 0x80073B17），改用 MainResourceMap.TryGetValue
    // （缺失返回 null 不抛）。资源 id 形如 "Resources/<name>"（Resources = Resources.resw 派生 map）。
    private static readonly ResourceMap Map = new ResourceManager().MainResourceMap;

    // 与 x:Uid 对齐的属性后缀：这些是 resw name 里点分的「属性限定符」，不能转成斜杠。
    // 其余点都是命名空间分隔符 → 转成斜杠（resw name 不能含点的命名空间段）。
    private static readonly string[] PropSuffixes =
        { ".Text", ".Header", ".Content", ".PlaceholderText", ".OnContent", ".OffContent" };

    /// <summary>按点分 key 取本地化串；缺失时回退 key 本身，便于静态核对暴露遗漏。</summary>
    public static string T(string key)
    {
        // 去掉属性后缀（如 .Text）：MRT Core 把带 .Text 的条目当作 x:Uid 属性资源，代码 TryGetValue
        // 取不到；因此 resw 里给代码取的串用「无后缀」名，这里统一剥掉后缀再按斜杠路径查。
        foreach (var p in PropSuffixes)
        {
            if (key.EndsWith(p, System.StringComparison.Ordinal))
            {
                key = key.Substring(0, key.Length - p.Length);
                break;
            }
        }
        var name = key.Replace('.', '/');
        // 先带 map 前缀再裸名；TryGetValue 缺失返回 null 不抛，最终回退 name（绝不崩）。
        foreach (var id in new[] { "Resources/" + name, name })
        {
            try
            {
                var c = Map.TryGetValue(id);
                if (c is not null && !string.IsNullOrEmpty(c.ValueAsString)) return c.ValueAsString;
            }
            catch { }
        }
        return name;
    }

    /// <summary>带占位符的格式化串（resw 里用 {0}/{1}…）。</summary>
    public static string T(string key, params object[] args) =>
        string.Format(T(key), args);
}
