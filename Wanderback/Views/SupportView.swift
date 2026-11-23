import SwiftUI

/// Écran « Soutenir Wanderback » : un mot de Bastien et les trois pourboires
/// « Offre-moi un café », avec leur prix localisé fourni par StoreKit.
struct SupportView: View {
    @Environment(TipStore.self) private var tipStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SceneBackground()

            ScrollView {
                VStack(spacing: 40.scaled) {
                    header
                    message
                    // Au-dessus des produits : reste visible juste après l'achat, sans défiler
                    statusMessage
                    productsSection
                    closeButton
                }
                .frame(maxWidth: 1000.scaled)
                .padding(.horizontal, Device.isPhone ? 24 : 60.scaled)
                .padding(.vertical, 60.scaled)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 620, height: 720)
        #endif
        .animation(Theme.focusAnimation, value: tipStore.purchaseState)
        .task { await tipStore.loadProducts() }
        .onAppear {
            // Une erreur d'une visite précédente n'a plus lieu d'être affichée ;
            // un remerciement (Ask to Buy validé entre-temps), si.
            if case .failed = tipStore.purchaseState { tipStore.dismissMessage() }
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 20.scaled) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40.scaled))
                .foregroundStyle(Theme.signatureGradient)
                .frame(width: 96.scaled, height: 96.scaled)
                .background(Color.white.opacity(0.08), in: Circle())
            GradientText(text: "Soutenir Wanderback", size: 60, tracking: -1)
                .multilineTextAlignment(.center)
        }
    }

    private var message: some View {
        VStack(spacing: 14.scaled) {
            Text("""
            Wanderback est gratuit, sans publicité, et vos photos ne quittent jamais votre \
            appareil. Si le jeu vous a fait revivre de beaux souvenirs, vous pouvez m'offrir \
            un café pour soutenir son développement. Merci !
            """)
            Text("Bastien")
                .italic()
                .foregroundStyle(Theme.textTertiary)
        }
        .font(.system(size: 26.scaled))
        .foregroundStyle(Theme.textSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Produits

    @ViewBuilder
    private var productsSection: some View {
        switch tipStore.loadState {
        case .idle, .loading:
            ProgressView()
                .tint(Theme.textSecondary)
                .padding(40.scaled)
        case .unavailable:
            Text("Les dons ne sont pas disponibles pour le moment.")
                .font(.system(size: 24.scaled))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        case .loaded(let products):
            VStack(spacing: 18.scaled) {
                ForEach(products) { product in
                    Button {
                        Task { await tipStore.purchase(product) }
                    } label: {
                        TipRowLabel(
                            product: product,
                            isPurchasing: tipStore.purchaseState == .purchasing(productID: product.id)
                        )
                    }
                    .buttonStyle(TipRowButtonStyle())
                    .disabled(tipStore.isPurchasing)
                    .accessibilityLabel("\(product.displayName), \(product.displayPrice)")
                }
            }
        }
    }

    // MARK: - Messages après achat

    @ViewBuilder
    private var statusMessage: some View {
        switch tipStore.purchaseState {
        case .thanks:
            statusBanner(
                icon: "heart.fill",
                color: Theme.success,
                title: "Merci beaucoup !",
                detail: "Votre soutien me touche et m'aide à faire grandir Wanderback."
            )
        case .pending:
            statusBanner(
                icon: "hourglass",
                color: Theme.amber,
                title: "Achat en attente",
                detail: "Il sera finalisé dès qu'il aura été approuvé."
            )
        case .failed(let message):
            statusBanner(
                icon: "exclamationmark.triangle.fill",
                color: Theme.error,
                title: "Achat non abouti",
                detail: message
            )
        case .idle, .purchasing:
            EmptyView()
        }
    }

    private func statusBanner(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 20.scaled) {
            Image(systemName: icon)
                .font(.system(size: 30.scaled, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 6.scaled) {
                Text(title)
                    .font(.system(size: 28.scaled, weight: .heavy))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 22.scaled))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(28.scaled)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 24.scaled))
        .overlay(
            RoundedRectangle(cornerRadius: 24.scaled)
                .strokeBorder(color.opacity(0.5), lineWidth: 2)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fermer

    private var closeButton: some View {
        Button("Fermer") {
            tipStore.dismissMessage()
            dismiss()
        }
        .buttonStyle(SecondaryPillButtonStyle(horizontalPadding: 50, verticalPadding: 18, fontSize: 24))
        #if os(macOS)
        .keyboardShortcut(.cancelAction)
        #endif
    }
}

// MARK: - Ligne produit

private struct TipRowLabel: View {
    let product: TipProduct
    let isPurchasing: Bool

    var body: some View {
        HStack(spacing: 24.scaled) {
            Image(systemName: product.symbolName)
                .font(.system(size: 28.scaled))
                .foregroundStyle(.white)
                .frame(width: 64.scaled, height: 64.scaled)
                .background(Color.white.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4.scaled) {
                Text(product.displayName)
                    .font(.system(size: 30.scaled, weight: .heavy))
                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.system(size: 21.scaled))
                        .opacity(0.7)
                }
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 12.scaled)

            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(Theme.inkDark)
                } else {
                    Text(product.displayPrice)
                        .font(.system(size: 26.scaled, weight: .heavy))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(Theme.inkDark)
            .padding(.horizontal, 26.scaled)
            .padding(.vertical, 12.scaled)
            .frame(minWidth: 130.scaled)
            .background(Theme.signatureGradient, in: Capsule())
        }
        .padding(24.scaled)
        .frame(maxWidth: .infinity)
    }
}

/// Carte translucide (même surface que les cartes réponse), mise en avant au focus / survol.
private struct TipRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TipRowStyledLabel(configuration: configuration)
    }

    private struct TipRowStyledLabel: View {
        @Environment(\.isFocused) private var isFocused
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration

        private var isHighlighted: Bool { isFocused || isHovered || configuration.isPressed }

        var body: some View {
            configuration.label
                .foregroundStyle(.white)
                .background(Theme.answerSurface, in: RoundedRectangle(cornerRadius: 26.scaled))
                .overlay(
                    RoundedRectangle(cornerRadius: 26.scaled)
                        .strokeBorder(isHighlighted ? Color.white : Theme.answerBorder, lineWidth: isHighlighted ? 3 : 1.5)
                )
                .opacity(isEnabled ? 1 : 0.6)
                .shadow(color: isHighlighted ? Theme.focusShadow : .clear, radius: 20, y: 14)
                .scaleEffect(isHighlighted ? 1.03 : 1.0)
                .animation(Theme.focusAnimation, value: isHighlighted)
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
        }
    }
}

#Preview {
    SupportView()
        .environment(TipStore.shared)
}
