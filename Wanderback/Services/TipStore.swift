import Foundation
import Observation
import StoreKit

// Achats intégrés « Offre-moi un café » : trois pourboires consommables, sans contenu
// débloqué. Les prix affichés viennent toujours de StoreKit (prix localisé de l'App Store),
// jamais d'une valeur codée en dur.

/// Identifiants des trois pourboires, identiques à ceux créés dans App Store Connect
/// et dans `WanderbackTests/Wanderback.storekit`.
enum TipProductID: String, CaseIterable, Sendable {
    case small = "com.bastien.Wanderback.tip.small"
    case medium = "com.bastien.Wanderback.tip.medium"
    case large = "com.bastien.Wanderback.tip.large"

    /// Symbole SF affiché à côté du produit.
    var symbolName: String {
        switch self {
        case .small: "cup.and.saucer.fill"
        case .medium: "mug.fill"
        case .large: "gift.fill"
        }
    }
}

/// Un pourboire tel que renvoyé par la boutique, découplé de `StoreKit.Product`
/// pour que le service soit testable sans App Store.
struct TipProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    /// Prix localisé fourni par StoreKit (« 0,99 € », « $0.99 »…).
    let displayPrice: String
    /// Prix numérique, utilisé seulement pour trier du plus petit au plus grand.
    let price: Decimal

    var symbolName: String {
        TipProductID(rawValue: id)?.symbolName ?? "cup.and.saucer.fill"
    }
}

/// Issue d'un achat qui n'a pas levé d'erreur.
enum TipPurchaseOutcome: Equatable, Sendable {
    case success
    case userCancelled
    /// Achat en attente d'une validation extérieure (Ask to Buy, contrôle parental, SCA…).
    case pending
}

enum TipStoreError: Error, Equatable {
    case productNotFound
    case failedVerification
}

/// Accès à la boutique. L'implémentation réelle passe par StoreKit 2 ;
/// les tests en injectent une fausse.
protocol TipStoreBackend: AnyObject {
    func loadProducts(ids: [String]) async throws -> [TipProduct]
    func purchase(productID: String) async throws -> TipPurchaseOutcome
    /// Transactions terminées hors du parcours d'achat direct (Ask to Buy validé plus tard,
    /// achat interrompu par un plantage, achat fait sur un autre appareil) : identifiant du
    /// produit, une fois la transaction vérifiée et finalisée.
    func completedTransactions() -> AsyncStream<String>
}

// MARK: - Service

@Observable
final class TipStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([TipProduct])
        /// Aucun produit trouvé (pas encore créés dans App Store Connect, contrat non
        /// signé…) ou boutique injoignable : le bouton d'accès reste masqué.
        case unavailable
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing(productID: String)
        case thanks
        case pending
        case failed(message: String)
    }

    /// Instance de l'app, branchée sur StoreKit.
    static let shared = TipStore(backend: StoreKitTipBackend())

    private(set) var loadState: LoadState = .idle
    private(set) var purchaseState: PurchaseState = .idle

    private let backend: TipStoreBackend
    private var updatesTask: Task<Void, Never>?

    init(backend: TipStoreBackend) {
        self.backend = backend
    }

    /// Produits disponibles, du moins cher au plus cher (vide si rien n'est chargé).
    var products: [TipProduct] {
        if case .loaded(let products) = loadState { products } else { [] }
    }

    var isAvailable: Bool { !products.isEmpty }

    var isPurchasing: Bool {
        if case .purchasing = purchaseState { true } else { false }
    }

    /// À appeler au lancement de l'app : écoute les transactions en arrière-plan
    /// (une seule fois) puis charge les produits.
    func start() async {
        startObservingTransactions()
        await loadProducts()
    }

    func startObservingTransactions() {
        guard updatesTask == nil else { return }
        let stream = backend.completedTransactions()
        updatesTask = Task { [weak self] in
            for await _ in stream {
                self?.purchaseState = .thanks
            }
        }
    }

    /// Charge les produits ; sans effet s'ils sont déjà chargés ou en cours de chargement.
    func loadProducts() async {
        switch loadState {
        case .loading, .loaded: return
        case .idle, .unavailable: break
        }
        loadState = .loading
        do {
            let ids = TipProductID.allCases.map(\.rawValue)
            let products = try await backend.loadProducts(ids: ids)
                .filter { ids.contains($0.id) }
                .sorted { $0.price < $1.price }
            loadState = products.isEmpty ? .unavailable : .loaded(products)
        } catch {
            loadState = .unavailable
        }
    }

    func purchase(_ product: TipProduct) async {
        guard !isPurchasing else { return }
        purchaseState = .purchasing(productID: product.id)
        do {
            switch try await backend.purchase(productID: product.id) {
            case .success: purchaseState = .thanks
            case .userCancelled: purchaseState = .idle
            case .pending: purchaseState = .pending
            }
        } catch {
            purchaseState = .failed(message: Self.message(for: error))
        }
    }

    /// Referme le message de remerciement, d'attente ou d'erreur.
    func dismissMessage() {
        guard !isPurchasing else { return }
        purchaseState = .idle
    }

    /// Message neutre affiché après un échec.
    static func message(for error: Error) -> String {
        if isNetworkError(error) {
            return "Impossible de joindre l'App Store. Vérifiez votre connexion puis réessayez."
        }
        return "L'achat n'a pas pu aboutir. Réessayez un peu plus tard."
    }

    static func isNetworkError(_ error: Error) -> Bool {
        if case StoreKitError.networkError = error { return true }
        if error is URLError { return true }
        return false
    }
}

// MARK: - StoreKit 2

final class StoreKitTipBackend: TipStoreBackend {
    private var productsByID: [String: Product] = [:]

    func loadProducts(ids: [String]) async throws -> [TipProduct] {
        let products = try await Product.products(for: ids)
        for product in products {
            productsByID[product.id] = product
        }
        return products.map {
            TipProduct(
                id: $0.id,
                displayName: $0.displayName,
                description: $0.description,
                displayPrice: $0.displayPrice,
                price: $0.price
            )
        }
    }

    func purchase(productID: String) async throws -> TipPurchaseOutcome {
        guard let product = productsByID[productID] else { throw TipStoreError.productNotFound }
        switch try await product.purchase() {
        case .success(let verification):
            // Un pourboire ne débloque rien : la transaction est finalisée même si la
            // vérification échoue, sinon elle reviendrait indéfiniment dans `Transaction.updates`.
            let transaction = Self.transaction(from: verification)
            await transaction.finish()
            guard case .verified = verification else { throw TipStoreError.failedVerification }
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .userCancelled
        }
    }

    func completedTransactions() -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                // D'abord les transactions restées non finalisées (app quittée en plein achat),
                // puis les nouvelles au fil de l'eau (Ask to Buy validé, autre appareil…).
                for await verification in Transaction.unfinished {
                    await Self.finish(verification, continuation: continuation)
                }
                for await verification in Transaction.updates {
                    await Self.finish(verification, continuation: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func finish(
        _ verification: VerificationResult<Transaction>,
        continuation: AsyncStream<String>.Continuation
    ) async {
        let transaction = transaction(from: verification)
        await transaction.finish()
        // Remboursement ou révocation : rien à remercier.
        guard case .verified = verification, transaction.revocationDate == nil else { return }
        continuation.yield(transaction.productID)
    }

    private static func transaction(from verification: VerificationResult<Transaction>) -> Transaction {
        switch verification {
        case .verified(let transaction), .unverified(let transaction, _): transaction
        }
    }
}
