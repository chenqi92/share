using System;
using System.IO;
using System.Runtime.InteropServices;

namespace MeshDrop.Models;

/// <summary>
/// 开机自启（登录时启动）。unpackaged WinUI 没有 MSIX StartupTask，这里走传统
/// 「启动」文件夹快捷方式：%AppData%\Microsoft\Windows\Start Menu\Programs\Startup\MeshDrop.lnk。
///
/// 为什么用 Startup 文件夹 + .lnk 而非注册表 Run：注册表 Run 需 Microsoft.Win32.Registry，
/// 在 net*-windows + WinUI（未启用 UseWPF/UseWindowsForms）下并非默认引用、会带来额外依赖；
/// 而创建 .lnk 只用 COM IShellLink（shell32 内置，无需任何 NuGet 包），per-user、免管理员。
/// 全部 best-effort：失败静默，不影响主功能。
/// </summary>
public static class LaunchAtLogin
{
    private const string LinkName = "MeshDrop.lnk";

    private static string StartupDir => Environment.GetFolderPath(Environment.SpecialFolder.Startup);
    private static string LinkPath => Path.Combine(StartupDir, LinkName);

    /// <summary>「启动」文件夹是否已有本机自启快捷方式。</summary>
    public static bool IsEnabled
    {
        get
        {
            try { return File.Exists(LinkPath); }
            catch { return false; }
        }
    }

    /// <summary>开/关自启。enabled=true 写入指向当前 exe 的 .lnk；false 删除。失败返回 false。</summary>
    public static bool Set(bool enabled)
    {
        try
        {
            if (enabled)
            {
                var exe = ExePath();
                if (string.IsNullOrEmpty(exe)) return false;
                Directory.CreateDirectory(StartupDir);
                CreateShortcut(LinkPath, exe);
                return File.Exists(LinkPath);
            }
            else
            {
                if (File.Exists(LinkPath)) File.Delete(LinkPath);
                return !File.Exists(LinkPath);
            }
        }
        catch { return false; }
    }

    private static string ExePath()
    {
        var path = Environment.ProcessPath;
        if (!string.IsNullOrEmpty(path)) return path!;
        try { return System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? ""; }
        catch { return ""; }
    }

    private static void CreateShortcut(string linkPath, string targetExe)
    {
        var link = (IShellLinkW)new ShellLink();
        link.SetPath(targetExe);
        var workDir = Path.GetDirectoryName(targetExe);
        if (!string.IsNullOrEmpty(workDir)) link.SetWorkingDirectory(workDir);
        link.SetDescription("MeshDrop");
        ((IPersistFile)link).Save(linkPath, fRemember: true);
    }

    // ── COM interop：IShellLinkW + IPersistFile（shell32 / ole32 内置，无需 NuGet） ──

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    private sealed class ShellLink { }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    private interface IShellLinkW
    {
        void GetPath([MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cch, IntPtr pfd, int fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
        void Resolve(IntPtr hwnd, int fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("0000010b-0000-0000-C000-000000000046")]
    private interface IPersistFile
    {
        void GetClassID(out Guid pClassID);
        [PreserveSig] int IsDirty();
        void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, int dwMode);
        void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, [MarshalAs(UnmanagedType.Bool)] bool fRemember);
        void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
        void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }
}
