import CoreGraphics
import Testing
@testable import Wanderback

/// Mise en page selon la largeur de la fenêtre : seuil compact / large et échelle iOS.
/// Fonctions pures, testées sur macOS comme sur iOS.
struct LayoutStyleTests {
    // MARK: - LayoutStyle

    @Test(arguments: [320, 375, 393, 402, 440, 466, 559.5] as [CGFloat])
    func largeurDeTelephoneEstCompacte(width: CGFloat) {
        #expect(LayoutStyle.forWidth(width) == .compact)
        #expect(LayoutStyle.forWidth(width).isCompact)
    }

    @Test(arguments: [560, 669, 744, 1133, 1180, 1376] as [CGFloat])
    func largeurDIPadOuEcranOuvertEstLarge(width: CGFloat) {
        #expect(LayoutStyle.forWidth(width) == .large)
        #expect(!LayoutStyle.forWidth(width).isCompact)
    }

    @Test func seuilA560Points() {
        #expect(LayoutStyle.compactWidthThreshold == 560)
    }

    // MARK: - Échelle iOS

    /// Rendu historique conservé : 0,58 sur tous les iPhone en portrait.
    @Test(arguments: [0, 320, 375, 393, 402, 430, 440] as [CGFloat])
    func echelleDesIPhoneInchangee(width: CGFloat) {
        #expect(Theme.scale(forWindowWidth: width) == 0.58)
    }

    /// Rendu historique conservé : 0,7 sur tous les iPad plein écran, en portrait
    /// (744 pt pour l'iPad mini, 1032 pt pour l'iPad Pro 13") comme en paysage.
    @Test(arguments: [744, 820, 834, 1032, 1133, 1180, 1210, 1366, 1376, 2000] as [CGFloat])
    func echelleDesIPadPleinEcranInchangee(width: CGFloat) {
        #expect(Theme.scale(forWindowWidth: width) == 0.7)
    }

    @Test func echelleContinueEntreLesBornes() {
        // Milieu exact de l'intervalle 440 → 744 pt
        #expect(abs(Theme.scale(forWindowWidth: 592) - 0.64) < 0.0001)

        var previous = Theme.scale(forWindowWidth: 400)
        for width in stride(from: 401, through: 1100, by: 1) {
            let scale = Theme.scale(forWindowWidth: CGFloat(width))
            #expect(scale >= previous, "l'échelle doit croître avec la largeur (\(width) pt)")
            #expect(scale - previous < 0.001, "pas de saut d'échelle (\(width) pt)")
            #expect((0.58...0.7).contains(scale))
            previous = scale
        }
    }

    @Test func echelleIOSDUneLargeurNonMesureeResteTelephone() {
        #expect(Theme.scale(forWindowWidth: -10) == 0.58)
    }

    // MARK: - Mesures partagées

    @Test func mesuresGardentLaLargeur() {
        let metrics = LayoutMetrics()
        metrics.update(windowWidth: 669)
        #expect(metrics.windowWidth == 669)
        #if os(iOS)
        #expect(metrics.scale == Theme.scale(forWindowWidth: 669))
        #elseif os(macOS)
        // macOS : échelle fixe, la largeur ne la change pas
        #expect(metrics.scale == 0.62)
        #endif
    }
}
