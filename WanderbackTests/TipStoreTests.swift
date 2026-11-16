import Foundation
import StoreKit
import Testing
@testable import Wanderback

/// Fausse boutique : renvoie ce qu'on lui demande, sans App Store.
final class FakeTipBackend: TipStoreBackend {
    var productsResult: Result<[TipProduct], Error> = .success([])
    var purchaseResult: Result<TipPurchaseOutcome, Error> = .success(.success)
    private(set) var loadCallCount = 0
    private(set) var requestedIDs: [String] = []
    private(set) var purchasedIDs: [String] = []

    let updates: AsyncStream<String>
    let updatesContinuation: AsyncStream<String>.Continuation

    init() {
        (updates, updatesContinuation) = AsyncStream.makeStream(of: String.self)
    }

    func loadProducts(ids: [String]) async throws -> [TipProduct] {
        loadCallCount += 1
        requestedIDs = ids
        return try productsResult.get()
    }

    func purchase(productID: String) async throws -> TipPurchaseOutcome {
        purchasedIDs.append(productID)
        return try purchaseResult.get()
    }

    func completedTransactions() -> AsyncStream<String> { updates }
}

private func product(_ id: TipProductID, _ price: Decimal) -> TipProduct {
    TipProduct(
        id: id.rawValue,
        displayName: "\(id)",
        description: "",
        displayPrice: "\(price) €",
        price: price
    )
}

private let allProducts = [
    product(.large, 4.99),
    product(.small, 0.99),
    product(.medium, 1.99),
]

@Suite("TipStore — chargement")
struct TipStoreLoadingTests {
    @Test func demandeLesTroisIdentifiants() async {
        let backend = FakeTipBackend()
        let store = TipStore(backend: backend)

        await store.loadProducts()

        #expect(backend.requestedIDs == [
            "com.bastien.Wanderback.tip.small",
            "com.bastien.Wanderback.tip.medium",
            "com.bastien.Wanderback.tip.large",
        ])
    }

    @Test func trieLesProduitsParPrixCroissant() async {
        let backend = FakeTipBackend()
        backend.productsResult = .success(allProducts)
        let store = TipStore(backend: backend)

        await store.loadProducts()

        #expect(store.products.map(\.id) == TipProductID.allCases.map(\.rawValue))
        #expect(store.isAvailable)
    }

    @Test func ignoreLesProduitsInconnus() async {
        let backend = FakeTipBackend()
        let intrus = TipProduct(id: "autre", displayName: "?", description: "", displayPrice: "0", price: 0)
        backend.productsResult = .success([intrus, product(.small, 0.99)])
        let store = TipStore(backend: backend)

        await store.loadProducts()

        #expect(store.products.map(\.id) == [TipProductID.small.rawValue])
    }

    @Test func produitsIntrouvablesRendentLaBoutiqueIndisponible() async {
        let backend = FakeTipBackend()
        backend.productsResult = .success([])
        let store = TipStore(backend: backend)

        await store.loadProducts()

        #expect(store.loadState == .unavailable)
        #expect(!store.isAvailable)
    }

    @Test func echecReseauAuChargementRendLaBoutiqueIndisponible() async {
        let backend = FakeTipBackend()
        backend.productsResult = .failure(StoreKitError.networkError(URLError(.notConnectedToInternet)))
        let store = TipStore(backend: backend)

        await store.loadProducts()

        #expect(store.loadState == .unavailable)
    }

    @Test func reessaieApresUnEchecMaisPasUneFoisCharge() async {
        let backend = FakeTipBackend()
        backend.productsResult = .failure(URLError(.timedOut))
        let store = TipStore(backend: backend)

        await store.loadProducts()
        backend.productsResult = .success(allProducts)
        await store.loadProducts()
        await store.loadProducts()

        #expect(backend.loadCallCount == 2)
        #expect(store.products.count == 3)
    }
}

@Suite("TipStore — achat")
struct TipStorePurchaseTests {
    private func loadedStore(_ backend: FakeTipBackend) async -> TipStore {
        backend.productsResult = .success(allProducts)
        let store = TipStore(backend: backend)
        await store.loadProducts()
        return store
    }

    @Test func achatReussiAfficheLeRemerciement() async {
        let backend = FakeTipBackend()
        backend.purchaseResult = .success(.success)
        let store = await loadedStore(backend)

        await store.purchase(store.products[1])

        #expect(backend.purchasedIDs == [TipProductID.medium.rawValue])
        #expect(store.purchaseState == .thanks)
    }

    @Test func achatAnnuleRevientAuRepos() async {
        let backend = FakeTipBackend()
        backend.purchaseResult = .success(.userCancelled)
        let store = await loadedStore(backend)

        await store.purchase(store.products[0])

        #expect(store.purchaseState == .idle)
    }

    @Test func achatEnAttenteAskToBuy() async {
        let backend = FakeTipBackend()
        backend.purchaseResult = .success(.pending)
        let store = await loadedStore(backend)

        await store.purchase(store.products[0])

        #expect(store.purchaseState == .pending)
    }

    @Test func echecReseauAfficheUnMessageDeConnexion() async {
        let backend = FakeTipBackend()
        backend.purchaseResult = .failure(StoreKitError.networkError(URLError(.networkConnectionLost)))
        let store = await loadedStore(backend)

        await store.purchase(store.products[0])

        guard case .failed(let message) = store.purchaseState else {
            Issue.record("état attendu : .failed, obtenu \(store.purchaseState)")
            return
        }
        #expect(message.contains("connexion"))
    }

    @Test func autreEchecAfficheUnMessageNeutre() async {
        let backend = FakeTipBackend()
        backend.purchaseResult = .failure(TipStoreError.failedVerification)
        let store = await loadedStore(backend)

        await store.purchase(store.products[2])

        #expect(store.purchaseState == .failed(message: TipStore.message(for: TipStoreError.failedVerification)))
        #expect(!TipStore.isNetworkError(TipStoreError.failedVerification))
    }

    @Test func fermerLeMessageRevientAuRepos() async {
        let backend = FakeTipBackend()
        let store = await loadedStore(backend)

        await store.purchase(store.products[0])
        store.dismissMessage()

        #expect(store.purchaseState == .idle)
    }

    @Test func transactionValideePlusTardAfficheLeRemerciement() async throws {
        let backend = FakeTipBackend()
        backend.purchaseResult = .success(.pending)
        let store = await loadedStore(backend)
        store.startObservingTransactions()
        await store.purchase(store.products[0])

        backend.updatesContinuation.yield(TipProductID.small.rawValue)

        // Laisse la tâche d'écoute consommer l'événement
        for _ in 0..<100 where store.purchaseState != .thanks {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.purchaseState == .thanks)
    }
}
