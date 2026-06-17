using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace MeshDrop.Discovery;

internal static class NetworkInterfaceSelector
{
    private static readonly string[] VirtualInterfaceHints =
    [
        "bluetooth",
        "clash",
        "docker",
        "hyper-v",
        "loopback",
        "openvpn",
        "sangfor",
        "singbox",
        "tap",
        "tailscale",
        "tun",
        "venUS sslvpn",
        "virtual",
        "vmware",
        "wintun",
        "wireguard",
        "wsl",
        "zerotier",
    ];

    public static IReadOnlyList<NetworkInterface> GetPreferredInterfaces()
    {
        var up = NetworkInterface.GetAllNetworkInterfaces()
            .Where(IsUsable)
            .Select(nic => new ScoredInterface(nic, Score(nic)))
            .Where(x => x.Score > 0)
            .OrderByDescending(x => x.Score)
            .Select(x => x.Interface)
            .ToList();

        var preferred = up.Where(nic => !LooksVirtual(nic)).ToList();
        return preferred.Count > 0 ? preferred : up;
    }

    public static IReadOnlyList<IPAddress> GetPreferredIPv4Addresses()
    {
        return GetPreferredInterfaces()
            .SelectMany(GetIPv4Addresses)
            .Distinct()
            .ToList();
    }

    public static string ResolvePrimaryIPv4()
    {
        return GetPreferredIPv4Addresses().FirstOrDefault()?.ToString() ?? "127.0.0.1";
    }

    public static IEnumerable<NetworkInterface> FilterPreferred(IEnumerable<NetworkInterface> interfaces)
    {
        var selected = interfaces.Where(IsUsable).Where(nic => !LooksVirtual(nic)).ToList();
        if (selected.Count > 0) return selected;
        return interfaces.Where(IsUsable).ToList();
    }

    public static IEnumerable<NetworkInterface> FilterDiscoveryInterfaces(IEnumerable<NetworkInterface> interfaces)
    {
        return interfaces
            .Where(IsUsable)
            .OrderByDescending(Score)
            .ToList();
    }

    private static bool IsUsable(NetworkInterface nic)
    {
        if (nic.OperationalStatus != OperationalStatus.Up) return false;
        if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) return false;
        if (!nic.SupportsMulticast) return false;
        return GetIPv4Addresses(nic).Any();
    }

    private static int Score(NetworkInterface nic)
    {
        var ip = nic.GetIPProperties();
        var hasGateway = ip.GatewayAddresses.Any(g => IsUsableIPv4(g.Address));
        var score = hasGateway ? 100 : 10;

        score += nic.NetworkInterfaceType switch
        {
            NetworkInterfaceType.Wireless80211 => 40,
            NetworkInterfaceType.Ethernet => 35,
            NetworkInterfaceType.GigabitEthernet => 35,
            NetworkInterfaceType.FastEthernetFx => 30,
            NetworkInterfaceType.FastEthernetT => 30,
            NetworkInterfaceType.Tunnel => -80,
            _ => 0,
        };

        if (LooksVirtual(nic)) score -= 90;
        return score;
    }

    private static IEnumerable<IPAddress> GetIPv4Addresses(NetworkInterface nic)
    {
        return nic.GetIPProperties().UnicastAddresses
            .Where(addr => addr.Address.AddressFamily == AddressFamily.InterNetwork)
            .Select(addr => addr.Address)
            .Where(IsUsableIPv4);
    }

    private static bool IsUsableIPv4(IPAddress address)
    {
        if (IPAddress.IsLoopback(address)) return false;
        var bytes = address.GetAddressBytes();
        if (bytes[0] == 169 && bytes[1] == 254) return false;
        if (bytes[0] == 0) return false;
        return true;
    }

    private static bool LooksVirtual(NetworkInterface nic)
    {
        var text = $"{nic.Name} {nic.Description}".ToLowerInvariant();
        return VirtualInterfaceHints.Any(hint => text.Contains(hint.ToLowerInvariant(), StringComparison.Ordinal));
    }

    private sealed record ScoredInterface(NetworkInterface Interface, int Score);
}
