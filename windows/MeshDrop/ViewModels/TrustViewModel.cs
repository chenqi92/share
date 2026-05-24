using System.Collections.ObjectModel;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

public sealed class TrustViewModel
{
    private readonly ShareEngine _engine = ShareEngine.Shared;
    public ObservableCollection<MockTrust> Trusted { get; }
    public int Count => Trusted.Count;

    public TrustViewModel()
    {
        Trusted = new ProjectedCollection<TrustRecord, MockTrust>(
            _engine.Trusted, r => r.ToMock());
    }
}
