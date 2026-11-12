import Foundation

/// Szín ARGB egészként, a legacy témák és a megosztó szerver formátuma.
public struct ARGB: Codable, Hashable, Sendable {
    public var value: UInt32

    public init(_ value: UInt32) { self.value = value }

    /// `#RRGGBB` vagy `#AARRGGBB`, a `#` elhagyható.
    public init?(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6 || s.count == 8, let v = UInt32(s, radix: 16) else { return nil }
        value = s.count == 6 ? 0xFF00_0000 | v : v
    }

    private func channel(_ shift: UInt32) -> Double { Double((value >> shift) & 0xFF) / 255 }
    public var alpha: Double { channel(24) }
    public var red: Double { channel(16) }
    public var green: Double { channel(8) }
    public var blue: Double { channel(0) }

    /// Lineáris keverés: `t = 0` → ez a szín, `t = 1` → a másik.
    public func mixed(with other: ARGB, by t: Double) -> ARGB {
        func ch(_ shift: UInt32) -> UInt32 {
            let a = Double((value >> shift) & 0xFF), b = Double((other.value >> shift) & 0xFF)
            return UInt32((a + (b - a) * t).rounded()) << shift
        }
        return ARGB(ch(24) | ch(16) | ch(8) | ch(0))
    }
}
