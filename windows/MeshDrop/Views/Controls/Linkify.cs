using System;
using System.Text.RegularExpressions;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Microsoft.UI.Xaml.Media;
using Windows.ApplicationModel.DataTransfer;

namespace MeshDrop.Views.Controls;

/// <summary>
/// 附加属性：给 RichTextBlock 设纯文本，自动把 URL / 验证码识别成高亮内联段——
/// URL 高亮且点击用系统浏览器打开；验证码（4–8 位数字）高亮且点击复制到剪贴板。
/// 其余文本保持普通 Run（继承 RichTextBlock 的前景色，随气泡明暗自适应）。
/// 消息气泡、历史、剪贴板均可复用：只需 &lt;RichTextBlock ctrl:Linkify.Text="{x:Bind ...}"/&gt;。
/// </summary>
public static class Linkify
{
    // url 优先于 code：交替匹配时 URL 里的数字被 URL 段吞掉，不会再单独当验证码。
    private static readonly Regex Pattern = new(
        @"(?<url>https?://[^\s]+|www\.[^\s]+)|(?<code>(?<!\d)\d{4,8}(?!\d))",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private const string UrlTrailTrim = ".,;:!?)]}'\"，。！？）】";

    public static readonly DependencyProperty TextProperty = DependencyProperty.RegisterAttached(
        "Text", typeof(string), typeof(Linkify), new PropertyMetadata(null, OnTextChanged));

    public static string GetText(DependencyObject o) => (string)o.GetValue(TextProperty);
    public static void SetText(DependencyObject o, string v) => o.SetValue(TextProperty, v);

    private static void OnTextChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is RichTextBlock rtb) Build(rtb, e.NewValue as string ?? "");
    }

    private static void Build(RichTextBlock rtb, string text)
    {
        rtb.Blocks.Clear();
        var para = new Paragraph();

        var last = 0;
        foreach (Match m in Pattern.Matches(text))
        {
            if (m.Index > last) AddPlain(para, text.Substring(last, m.Index - last));

            if (m.Groups["url"].Success)
            {
                var raw = m.Value;
                var end = raw.Length;
                while (end > 0 && UrlTrailTrim.IndexOf(raw[end - 1]) >= 0) end--;
                AddUrl(para, raw.Substring(0, end));
                if (end < raw.Length) AddPlain(para, raw.Substring(end));
            }
            else
            {
                AddCode(para, m.Value);
            }
            last = m.Index + m.Length;
        }
        if (last < text.Length) AddPlain(para, text.Substring(last));

        rtb.Blocks.Add(para);
    }

    private static void AddPlain(Paragraph para, string s) => para.Inlines.Add(new Run { Text = s });

    private static void AddUrl(Paragraph para, string url)
    {
        var link = new Hyperlink { Foreground = Brush("MdSkyBrush") };
        var target = url.StartsWith("www.", StringComparison.OrdinalIgnoreCase) ? "https://" + url : url;
        if (Uri.TryCreate(target, UriKind.Absolute, out var uri)) link.NavigateUri = uri;
        ToolTipService.SetToolTip(link, url);
        link.Inlines.Add(new Run { Text = url });
        para.Inlines.Add(link);
    }

    private static void AddCode(Paragraph para, string code)
    {
        var link = new Hyperlink
        {
            Foreground = Brush("MdLimeDeepBrush"),
            UnderlineStyle = UnderlineStyle.None,
        };
        ToolTipService.SetToolTip(link, I18n.T("common.clickToCopy"));
        link.Inlines.Add(new Run { Text = code, FontWeight = FontWeights.SemiBold });
        link.Click += (_, _) =>
        {
            var dp = new DataPackage();
            dp.SetText(code);
            Clipboard.SetContent(dp);
        };
        para.Inlines.Add(link);
    }

    // 与 MsgBubble 一致用扁平索引器取主题画刷（运行时可解析 ThemeDictionaries）；缺失回落。
    private static Brush Brush(string key)
    {
        try { if (Application.Current.Resources[key] is Brush b) return b; }
        catch { }
        return new SolidColorBrush(Microsoft.UI.Colors.DodgerBlue);
    }
}
