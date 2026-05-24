using System.Threading.Tasks;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

/// <summary>
/// 简单代理：把 <see cref="ShareEngine.Shared"/> 的 ObservableCollections 透传给 XAML。
/// </summary>
public sealed class DeviceListViewModel
{
    public ShareEngine Engine { get; } = ShareEngine.Shared;

    public string DisplayName => Engine.DisplayName;
    public string FingerprintShort => Engine.Identity.Fingerprint[..16];

    public Task StartAsync() => Engine.StartAsync();
    public void Stop() => Engine.Stop();
}
