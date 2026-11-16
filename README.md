# 🗺️ Wanderback

> Jeu de reconnaissance de lieux à partir de tes photos de vacances · Apple TV (tvOS), Mac (macOS), iPad & iPhone (iOS)

Wanderback est une application tvOS, macOS et iOS (iPhone et iPad) qui pioche dans ta bibliothèque iCloud pour te faire deviner où ont été prises tes propres photos de voyage. Inspiré de GeoGuessr, mais avec tes souvenirs personnels.

## Concept

- La photo d'un de tes voyages s'affiche en plein écran
- Tu choisis parmi 4 lieux proposés (issus de ta propre bibliothèque)
- Deux modes : **Souvenir** (ambiance nostalgie, révélation cinématique) et **Challenge** (chrono + score)
- 100% local — aucune donnée ne quitte l'appareil

## Prérequis

- Apple TV 4K (2e ou 3e génération)
- tvOS 17.0+
- ou un Mac sous macOS 26+ (cible WanderbackMac)
- ou un iPhone / iPad sous iOS 26+ (cible WanderbackiOS)
- Bibliothèque iCloud avec au moins **4 destinations distinctes** avec GPS activé

## Documentation

| Fichier | Contenu |
|---|---|
| [`docs/specs.md`](docs/specs.md) | Spécifications produit complètes (vision, modes, flux, architecture) |
| [`docs/technique-et-setup.md`](docs/technique-et-setup.md) | UX TV, états de chargement, setup Xcode, GitHub, outils |
| [`docs/wireframes.html`](docs/wireframes.html) | Maquettes interactives des 6 écrans principaux (ouvrir dans un navigateur) |

## Stack technique

- **Swift 5.9+** / **SwiftUI**
- **PhotoKit** — accès bibliothèque iCloud
- **CoreLocation / CLGeocoder** — géocodage inverse (GPS → nom de ville)
- **MapKit** — carte animée sur l'écran de révélation
- **SwiftData** — cache local (index des lieux géocodés)
- **StoreKit 2** — achats intégrés facultatifs « Offre-moi un café » (3 pourboires consommables)

## Structure du projet

```
wanderback/
├── Wanderback.xcodeproj/
├── Wanderback/
│   ├── App/                    # Point d'entrée
│   ├── Models/                 # PhotoLocation, LocationCluster, GameRound...
│   ├── ViewModels/             # PhotoLibraryViewModel, GameViewModel...
│   ├── Views/                  # HomeView, GameView, RevealView...
│   ├── Services/               # PhotoIndexer, GeocoderService, QuestionGenerator
│   └── Persistence/            # LocationCache (SwiftData)
├── WanderbackTests/            # Tests unitaires + Wanderback.storekit (boutique locale)
└── docs/
```

## Démarrage

Voir [`docs/technique-et-setup.md`](docs/technique-et-setup.md) — section **4. Démarrage du Projet Xcode**.

## Tests

Tests unitaires (Swift Testing) dans `WanderbackTests/`, rattachés aux schémas `WanderbackMac`
(cible `WanderbackTests`) et `WanderbackiOS` (cible `WanderbackiOSTests`) :

```sh
xcodebuild -project Wanderback.xcodeproj -scheme WanderbackMac -destination 'platform=macOS' test
```

### Achats intégrés en local

`WanderbackTests/Wanderback.storekit` décrit les trois pourboires (`com.bastien.Wanderback.tip.small`,
`.tip.medium`, `.tip.large`). Il est branché sur l'action *Run* des schémas `WanderbackiOS` et
`WanderbackMac` : lancée depuis Xcode, l'app achète sur cette boutique locale, sans App Store ni
paiement réel (menu *Debug › StoreKit › Manage Transactions* pour voir les achats). Les tests
`StoreKitTipBackendTests` l'utilisent via `SKTestSession`. En production, les produits viennent
d'App Store Connect ; tant qu'ils n'y existent pas, le bouton « Soutenir » de l'accueil reste masqué.

## Roadmap

- **V1 — MVP** : indexation GPS, génération de questions, mode Challenge, écran de révélation
- **V2 — Enrichissement** : mode Souvenir cinématique, sélection par voyage/année
- **V3 — Social** : multijoueur local, Game Center, SharePlay
