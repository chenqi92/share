using System.Collections.ObjectModel;
using MeshDrop.Mock;

namespace MeshDrop.ViewModels;

public sealed class TrustViewModel
{
    public ObservableCollection<MockTrust> Trusted { get; } = MockObs.Trusted();
    public int Count => Trusted.Count;
}
