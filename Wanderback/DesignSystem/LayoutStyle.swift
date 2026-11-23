import SwiftUI
import Observation

// MARK: - Style de mise en page

/// Mise en page choisie d'après la largeur de la fenêtre, et non d'après le modèle
/// d'appareil : un iPad en Split View 1/3, l'écran extérieur d'un iPhone pliable ou un
/// iPhone ont la même contrainte de largeur, et le même iPhone pliable ouvert n'a plus
/// celle d'un téléphone.
///
/// - `compact` : reprend exactement l'ancienne branche « iPhone » des vues.
/// - `large` : reprend l'ancienne branche « iPad, Mac, Apple TV ».
///
/// Seul iOS mesure la fenêtre ; macOS et tvOS restent toujours en `large`.
enum LayoutStyle: Equatable, Sendable {
    case compact
    case large

    /// Largeur de fenêtre (pt) sous laquelle on passe en compact. Tous les iPhone en
    /// portrait (375 à 440 pt) sont en dessous, un iPad plein écran au-dessus.
    static let compactWidthThreshold: CGFloat = 560

    /// Style d'une fenêtre (ou d'une feuille) de cette largeur, en points.
    static func forWidth(_ width: CGFloat) -> LayoutStyle {
        width < compactWidthThreshold ? .compact : .large
    }

    var isCompact: Bool { self == .compact }
}

extension EnvironmentValues {
    /// Style de mise en page de la fenêtre, posé à la racine (`WanderbackApp`).
    /// Valeur par défaut `large` : macOS, tvOS, et les aperçus Xcode hors racine.
    @Entry var layoutStyle: LayoutStyle = .large
}

// MARK: - Mesures de la fenêtre

/// Mesures de la fenêtre, partagées hors de l'environnement SwiftUI.
///
/// `CGFloat.scaled` et `Int.scaled` (Theme.swift) sont des extensions de nombres,
/// appelées partout sans accès à l'environnement. Elles lisent donc `scale` ici. Comme
/// l'objet est `@Observable`, toute vue dont le `body` a lu `.scaled` est recalculée
/// quand l'échelle change (redimensionnement, Split View, pliage).
///
/// Limite connue : un seul jeu de mesures pour toute l'app. Avec deux fenêtres
/// Wanderback de largeurs différentes sur iPad, l'échelle suit la dernière mesurée ;
/// le `LayoutStyle`, lui, reste propre à chaque fenêtre.
@Observable
final class LayoutMetrics {
    static let shared = LayoutMetrics()

    /// Facteur d'échelle courant (voir `Theme.scale`).
    private(set) var scale: CGFloat

    /// Largeur mesurée de la fenêtre, en points (0 tant qu'aucune mesure n'est arrivée).
    @ObservationIgnored private(set) var windowWidth: CGFloat = 0

    init() {
        #if os(macOS)
        scale = 0.62
        #elseif os(iOS)
        // Avant la première mesure : valeur téléphone. La mesure arrive au premier
        // passage de mise en page, avant l'affichage.
        scale = Theme.scale(forWindowWidth: 0)
        #else
        scale = 1.0
        #endif
    }

    /// Appelé par la racine à chaque changement de largeur de la fenêtre (iOS).
    func update(windowWidth width: CGFloat) {
        windowWidth = width
        #if os(iOS)
        let newScale = Theme.scale(forWindowWidth: width)
        // N'invalide les vues que si l'échelle change vraiment (toutes les largeurs
        // d'iPhone donnent 0,58).
        if newScale != scale { scale = newScale }
        #endif
    }
}

// MARK: - Lecture de la largeur

extension View {
    /// À la racine de la fenêtre : mesure sa largeur, met à jour `LayoutMetrics` et
    /// pose le `LayoutStyle` dans l'environnement. Sans effet hors iOS.
    func windowLayout() -> some View {
        modifier(WindowLayoutModifier(updatesSharedMetrics: true))
    }

    /// Dans une feuille, plus étroite que la fenêtre qui la présente (iPad, écran
    /// ouvert) : pose le `LayoutStyle` de la feuille elle-même. Sans effet hors iOS.
    func sheetLayout() -> some View {
        modifier(WindowLayoutModifier(updatesSharedMetrics: false))
    }
}

private struct WindowLayoutModifier: ViewModifier {
    let updatesSharedMetrics: Bool

    #if os(iOS)
    @State private var style: LayoutStyle?
    @Environment(\.layoutStyle) private var inheritedStyle

    func body(content: Content) -> some View {
        content
            // Avant la première mesure, on garde le style hérité (ou `large`)
            .environment(\.layoutStyle, style ?? inheritedStyle)
            .onGeometryChange(for: CGFloat.self) { proxy in
                // Largeur totale, marges de sécurité latérales comprises : c'est la
                // fenêtre qu'on classe, pas la zone sûre.
                proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            } action: { width in
                if updatesSharedMetrics {
                    LayoutMetrics.shared.update(windowWidth: width)
                }
                let newStyle = LayoutStyle.forWidth(width)
                if newStyle != style { style = newStyle }
            }
    }
    #else
    func body(content: Content) -> some View { content }
    #endif
}
