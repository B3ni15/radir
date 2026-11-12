import Testing
@testable import RadirKit

@Suite struct PaletteTests {
    @Test func hexParsing() {
        #expect(ARGB(hex: "#2F6FEB")?.value == 0xFF2F_6FEB)
        #expect(ARGB(hex: "2f6feb")?.value == 0xFF2F_6FEB)
        #expect(ARGB(hex: "#802F6FEB")?.value == 0x802F_6FEB)
        #expect(ARGB(hex: "zz") == nil)
        #expect(ARGB(hex: "#12345") == nil)
    }

    @Test func components() {
        let c = ARGB(0x80FF_0000)
        #expect(abs(c.alpha - 128.0 / 255) < 0.0001)
        #expect(c.red == 1 && c.green == 0 && c.blue == 0)
    }

    @Test func brandAndGradeColors() {
        #expect(Palette.light.accent == ARGB(0xFF2F_6FEB))
        #expect(Palette.dark.accent == ARGB(0xFF6C_9BFF))
        #expect(Palette.dark.gradeColor(5) == ARGB(0xFF22_CCAD))
        #expect(Palette.light.gradeColor(1) == ARGB(0xFFFF_54A1))
        #expect(Palette.light.gradeColor(0) == nil)
        #expect(Palette.light.gradeColor(6) == nil)
    }

    @Test func averageColorInterpolates() {
        let p = Palette.light
        #expect(p.gradeColor(forAverage: 4) == p.gradeColor(4))
        #expect(p.gradeColor(forAverage: 5) == p.gradeColor(5))
        #expect(p.gradeColor(forAverage: 0.3) == p.gradeColor(1))
        #expect(ARGB(0xFF00_0000).mixed(with: ARGB(0xFFFF_FFFF), by: 0.5) == ARGB(0xFF80_8080))
        #expect(p.gradeColor(forAverage: 3.5) == p.gradeColor(3)!.mixed(with: p.gradeColor(4)!, by: 0.5))
    }
}
