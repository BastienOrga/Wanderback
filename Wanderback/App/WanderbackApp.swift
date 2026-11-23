import SwiftUI
import SwiftData

@main
struct WanderbackApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(OrientationLockDelegate.self) private var orientationLock
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(TipStore.shared)
                // Écoute de `Transaction.updates` dès le lancement, comme l'exige StoreKit
                .task { await TipStore.shared.start() }
                // iOS : style de mise en page et échelle d'après la largeur de la fenêtre
                .windowLayout()
                #if os(macOS)
                .frame(minWidth: 1024, minHeight: 640)
                #endif
        }
        .modelContainer(for: LocationCache.self)
        #if os(macOS)
        .defaultSize(width: 1280, height: 720)
        .commands {
            // Le jeu est mono-fenêtre : une seconde fenêtre relancerait une indexation complète
            CommandGroup(replacing: .newItem) { }
        }
        #endif
    }
}
