using System;
using System.Threading.Tasks;

namespace MeshDrop.Gateway;

/// <summary>
/// App 启动 gateway 后把实例发布到这里；ViewModel 订阅 Changed 拿 URL / pairing code，
/// 并可经 <see cref="SetEnabledAsync"/> 真正启停对外监听端口（Settings「启用 Web Gateway」开关）。
/// </summary>
public static class GatewayProbe
{
    private static WebGatewayHost? s_host;

    public static event Action? Changed;

    public static WebGatewayHost? Host => s_host;

    public static string? Url => s_host?.Url;
    public static string? PairingCode => s_host?.PairingCode;

    /// <summary>当前对外监听是否开启。未发布实例时视为关闭。</summary>
    public static bool IsRunning => s_host?.IsRunning ?? false;

    public static void Publish(WebGatewayHost host)
    {
        s_host = host;
        Changed?.Invoke();
    }

    /// <summary>
    /// Settings「启用 Web Gateway」开关：true 时启动监听，false 时停止并释放端口
    /// （fix #42——关掉开关必须真正关闭对外监听面，否则只是 UI 假象）。
    /// </summary>
    public static async Task SetEnabledAsync(bool enabled)
    {
        if (s_host is not { } host) return;
        if (enabled)
        {
            if (!host.IsRunning) await host.StartAsync();
        }
        else
        {
            if (host.IsRunning) host.Stop();
        }
        Changed?.Invoke();
    }

    public static void Clear(WebGatewayHost? host = null)
    {
        if (host is not null && !ReferenceEquals(s_host, host)) return;
        s_host = null;
        Changed?.Invoke();
    }
}
