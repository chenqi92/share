import SwiftUI

enum MeshDropColor {
    static let ink   = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let dink  = Color(red: 0.055, green: 0.047, blue: 0.035)
    static let dink2 = Color(red: 0.094, green: 0.086, blue: 0.071)
    static let dink3 = Color(red: 0.137, green: 0.125, blue: 0.102)

    static let dpaper      = Color(red: 0.910, green: 0.890, blue: 0.839)
    static let dpaperDim   = Color(red: 0.910, green: 0.890, blue: 0.839).opacity(0.65)
    static let dpaperMute  = Color(red: 0.910, green: 0.890, blue: 0.839).opacity(0.40)
    static let dline       = Color.white.opacity(0.10)
    static let dlineSoft   = Color.white.opacity(0.06)

    static let lime      = Color(red: 0.867, green: 0.976, blue: 0.294)
    static let limeDeep  = Color(red: 0.659, green: 0.784, blue: 0.000)
    static let limeWash  = Color(red: 0.867, green: 0.976, blue: 0.294).opacity(0.16)
    static let limeFill  = Color(red: 0.867, green: 0.976, blue: 0.294).opacity(0.32)

    static let flame      = Color(red: 1.000, green: 0.353, blue: 0.173)
    static let flameDeep  = Color(red: 0.780, green: 0.243, blue: 0.082)
    static let sky        = Color(red: 0.302, green: 0.722, blue: 1.000)
    static let error      = Color(red: 0.769, green: 0.196, blue: 0.169)

    /// 客厅环境光的 radial gradient 主背景
    static func ambient() -> RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.094, green: 0.082, blue: 0.067),
                Color(red: 0.043, green: 0.039, blue: 0.031),
                Color(red: 0.024, green: 0.020, blue: 0.020),
            ],
            center: .center,
            startRadius: 200,
            endRadius: 1200
        )
    }
}
