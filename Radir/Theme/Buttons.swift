import SwiftUI

extension View {
    /// Fő gomb: iOS 26-tól üveg, előtte a sima kiemelt gomb.
    @ViewBuilder
    func radirProminentButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func radirSecondaryButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}
