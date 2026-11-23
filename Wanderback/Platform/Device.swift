#if os(iOS)
import UIKit
#endif

/// Distinctions d'appareil qui ne peuvent pas se faire à la compilation : depuis le
/// portage iPhone, iPhone et iPad partagent le même binaire iOS, donc aucun `#if` ne
/// les sépare.
///
/// À ne pas utiliser pour la mise en page : les vues suivent la largeur de la fenêtre
/// (`LayoutStyle`, `Theme.scale`). Un iPhone pliable ouvert reste un « phone » mais
/// n'a plus la largeur d'un téléphone. Seul le verrou d'orientation s'en sert encore.
enum Device {
    /// Vrai uniquement sur iPhone. Faux sur iPad, Mac et Apple TV.
    static let isPhone: Bool = {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }()
}
