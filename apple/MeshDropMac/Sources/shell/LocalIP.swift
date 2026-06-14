import Foundation

/// 本机首选 IPv4 地址。
///
/// 优先真实局域网网卡（`en*`），跳过 VPN/隧道接口（`utun` / `ipsec` / `ppp` / `tun` / `tap`）
/// 与 CGNAT/基准网段（`198.18` / `198.19` / `100.64`）——否则开了代理（Clash/Surge 等 TUN 模式）
/// 时会错把隧道虚拟地址（如 `198.18.0.1`）当成本机局域网地址显示。
enum LocalIP {
    /// 返回最合适的本机 IPv4；全无可用接口时返回 nil。
    static func primaryIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var best: (rank: Int, ip: String)?
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            let flags = Int32(cur.pointee.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
                  (flags & IFF_LOOPBACK) == 0,
                  let sa = cur.pointee.ifa_addr,
                  sa.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: cur.pointee.ifa_name)
            var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len),
                              &hostBuf, socklen_t(hostBuf.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let host = String(cString: hostBuf)
            if host.hasPrefix("127.") || host.hasPrefix("169.254.") { continue }

            let isTunnel = ["utun", "ipsec", "ppp", "tun", "tap"].contains { name.hasPrefix($0) }
            let isFakeRange = host.hasPrefix("198.18.") || host.hasPrefix("198.19.") || host.hasPrefix("100.64.")
            let rank: Int
            if isTunnel || isFakeRange { rank = 0 }            // VPN/隧道：最低优先，仅在别无选择时用
            else if name.hasPrefix("en") { rank = 3 }          // 有线/Wi-Fi：最高优先
            else if name.hasPrefix("bridge") || name.hasPrefix("ap") { rank = 1 }
            else { rank = 2 }

            if best == nil || rank > best!.rank { best = (rank, host) }
        }
        return best?.ip
    }
}
