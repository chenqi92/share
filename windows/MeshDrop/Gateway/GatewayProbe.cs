using System;

namespace MeshDrop.Gateway;

/// <summary>
/// App 启动 gateway 后把实例发布到这里；ViewModel 订阅 Changed 拿 URL / pairing code。
/// </summary>
public static class GatewayProbe
{
    private static WebGatewayHost? s_host;

    public static event Action? Changed;

    public static WebGatewayHost? Host => s_host;

    public static string? Url => s_host?.Url;
    public static string? PairingCode => s_host?.PairingCode;

    public static void Publish(WebGatewayHost host)
    {
        s_host = host;
        Changed?.Invoke();
    }
}
