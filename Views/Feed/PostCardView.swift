import SwiftUI

struct PostCardView: View {
    let post: Post
    let onKudos: () -> Void
    @State private var showDetail = false
    @State private var showPaymentSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(Text(post.author?.name.prefix(1) ?? "?").font(.headline))

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Category badge
                Text("\(post.category.emoji) \(post.category.label)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(post.category).opacity(0.15))
                    .foregroundStyle(categoryColor(post.category))
                    .clipShape(Capsule())
            }

            // Image (if any)
            if let imageURL = post.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.secondary.opacity(0.2))
                }
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Text
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
            }

            // Payment bar (purchase posts with payment request)
            if post.category == .purchase, let request = post.paymentRequest {
                Button {
                    showPaymentSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text("💸")
                        Text("$\(request.totalAmount, specifier: "%.2f") split \(request.splits.count) way\(request.splits.count == 1 ? "" : "s")")
                            .font(.caption.bold())
                        Text("—")
                            .foregroundStyle(.secondary)
                        Text("\(request.paidCount) paid, \(request.pendingCount) pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPaymentSheet) {
                    PaymentRequestView(mode: .view(post: post))
                        .presentationDetents([.large])
                }
            }

            // Actions
            HStack(spacing: 20) {
                // Compact kudos button
                Button(action: onKudos) {
                    HStack(spacing: 4) {
                        Text(post.hasGivenKudos ? "🙌" : "👏")
                        Text("\(post.kudosCount) kudos")
                            .font(.subheadline)
                            .foregroundStyle(post.hasGivenKudos ? Color.orange : .secondary)
                    }
                }
                .buttonStyle(.plain)

                // Comment count tap target — opens PostDetailView
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: 4) {
                        Text("💬")
                        Text("\(post.comments?.count ?? 0) comment\(post.comments?.count == 1 ? "" : "s")")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // Tapping the card body also opens the detail view
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showDetail) {
            PostDetailView(post: post)
        }
    }

    private func categoryColor(_ cat: PostCategory) -> Color {
        switch cat {
        case .chore: return Color.blue
        case .purchase: return Color.green
        case .general: return Color.orange
        }
    }
}
