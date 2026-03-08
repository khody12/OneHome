import SwiftUI

// MARK: - CategorizeView

/// Step 2 of the post wizard. The user picks a category and adds an optional caption.
/// Receives the captured image (or nil) from CameraView and passes the category +
/// text forward to ReviewPostView.
struct CategorizeView: View {
    let capturedImage: UIImage?
    var onNext: (PostCategory, String, Bool) -> Void
    var onBack: () -> Void

    @State private var selectedCategory: PostCategory? = nil
    @State private var captionText: String = ""
    @State private var addPaymentRequest: Bool = false
    @State private var paymentAmount: Double = 0
    @FocusState private var captionFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Photo preview / placeholder ───────────────────────────
                photoPreview
                    .padding(.top, 16)

                // ── Category cards ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's this about?")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    ForEach(PostCategory.allCases, id: \.self) { category in
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategory == category,
                            onTap: { selectedCategory = category }
                        )
                        .padding(.horizontal, 20)
                    }
                }

                // ── Caption text field ────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("Caption")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    TextField("Add a caption (optional)...", text: $captionText, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .focused($captionFocused)
                }

                // ── Payment request toggle (purchase posts only) ───────────
                if selectedCategory == .purchase {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $addPaymentRequest) {
                            HStack(spacing: 8) {
                                Text("💸")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add payment request?")
                                        .font(.body.bold())
                                    Text("Split this purchase with roommates")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.orange)
                        .padding(.horizontal, 20)

                        if addPaymentRequest {
                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                TextField("0.00", value: $paymentAmount, format: .number.precision(.fractionLength(2)))
                                    .keyboardType(.decimalPad)
                                    .font(.headline.bold())
                                Spacer()
                                if paymentAmount > 0 {
                                    Text("Split with roommates on next step")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: addPaymentRequest)
                }

                // ── Navigation buttons ────────────────────────────────────
                HStack(spacing: 16) {
                    Button("← Back") {
                        onBack()
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    Button("Next →") {
                        guard let cat = selectedCategory else { return }
                        onNext(cat, captionText, addPaymentRequest && paymentAmount > 0)
                    }
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        selectedCategory == nil
                            ? Color.orange.opacity(0.4)
                            : Color.orange,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .disabled(selectedCategory == nil)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
    }

    // MARK: - Photo preview

    @ViewBuilder
    private var photoPreview: some View {
        if let image = capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 120)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No photo")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - CategoryCard

/// A large tappable card representing a single PostCategory.
/// Gets an orange border when selected.
private struct CategoryCard: View {
    let category: PostCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(category.emoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.label)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    Text(category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PostCategory subtitle helper

extension PostCategory {
    /// A short subtitle shown beneath the category label in the card.
    var subtitle: String {
        switch self {
        case .chore:    return "I did something useful"
        case .purchase: return "I spent money on us"
        case .general:  return "Just sharing something"
        }
    }
}
