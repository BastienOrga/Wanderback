import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Wanderback

/// Bout en bout avec le vrai backend StoreKit 2, sur la boutique locale décrite par
/// `Wanderback.storekit` (aucun appel à l'App Store, aucun paiement réel).
@Suite("StoreKitTipBackend — boutique locale", .serialized)
struct StoreKitTipBackendTests {
    /// Les réglages d'une session (erreur simulée, Ask to Buy) persistent d'un test et d'un
    /// lancement à l'autre : chaque test repart donc d'une boutique explicitement remise à zéro.
    private func makeSession() async throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Wanderback")
        session.disableDialogs = true
        session.askToBuyEnabled = false
        try await session.setSimulatedError(nil, forAPI: .purchase)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        session.clearTransactions()
        return session
    }

    @Test func chargeLesTroisCafesAvecLeurPrixLocalise() async throws {
        let session = try await makeSession()
        let store = TipStore(backend: StoreKitTipBackend())

        await store.loadProducts()

        #expect(store.products.map(\.id) == TipProductID.allCases.map(\.rawValue))
        #expect(store.products.allSatisfy { !$0.displayPrice.isEmpty })
        _ = session
    }

    @Test func achatSimuleReussi() async throws {
        let session = try await makeSession()
        let store = TipStore(backend: StoreKitTipBackend())
        await store.loadProducts()
        let small = try #require(store.products.first)

        await store.purchase(small)

        #expect(store.purchaseState == .thanks)
        #expect(session.allTransactions().contains { $0.productIdentifier == small.id })
    }

    @Test func achatEnAttenteAskToBuy() async throws {
        let session = try await makeSession()
        session.askToBuyEnabled = true
        let store = TipStore(backend: StoreKitTipBackend())
        await store.loadProducts()
        let product = try #require(store.products.first)

        await store.purchase(product)

        #expect(store.purchaseState == .pending)
    }

    @Test func echecReseauSimule() async throws {
        let session = try await makeSession()
        let store = TipStore(backend: StoreKitTipBackend())
        await store.loadProducts()
        let product = try #require(store.products.first)
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))),
            forAPI: .purchase
        )

        await store.purchase(product)

        guard case .failed(let message) = store.purchaseState else {
            Issue.record("état attendu : .failed, obtenu \(store.purchaseState)")
            return
        }
        #expect(message.contains("connexion"))
    }
}
