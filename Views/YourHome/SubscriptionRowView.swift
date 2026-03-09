import SwiftUI

struct SubscriptionRowView: View {
    let subscription: Subscription
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(subscription.serviceIcon)
                        .font(.title2)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(subscription.serviceName)
                            .font(.subheadline.bold())
                        Text("$\(String(format: "%.2f", subscription.costPerMember))/person · \(subscription.members.count) member\(subscription.members.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(String(format: "%.2f", subscription.monthlyCost))/mo")
                        .font(.caption.bold())
                        .foregroundStyle(Color.orange)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    Text("Bills on day \(subscription.billingDay) each month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: -8) {
                        ForEach(subscription.members.prefix(5)) { member in
                            Circle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 24, height: 24)
                                .overlay(Text(member.user?.name.prefix(1) ?? "?").font(.caption2.bold()))
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                        }
                        if subscription.members.count > 5 {
                            Text("+\(subscription.members.count - 5)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 12)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
