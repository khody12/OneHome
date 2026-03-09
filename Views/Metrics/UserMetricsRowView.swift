import SwiftUI

struct UserMetricsRowView: View {
    let rank: Int
    let metrics: UserMetrics
    let allMetrics: [UserMetrics]
    var isCurrentUser: Bool = false

    @State private var isExpanded = false

    var medal: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "💀"
        }
    }

    var isSlacking: Bool {
        metrics.isSlacking(comparedTo: allMetrics)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.28)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Avatar initial
                    ZStack {
                        Circle()
                            .fill(isCurrentUser ? Color.orange : Color.orange.opacity(0.25))
                            .frame(width: 38, height: 38)
                        Text(String(metrics.user?.name.prefix(1) ?? "?"))
                            .font(.headline)
                            .foregroundStyle(isCurrentUser ? .white : .orange)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(medal)
                                .font(.callout)
                            Text(metrics.user?.name ?? "Unknown")
                                .font(.headline)
                                .foregroundStyle(isCurrentUser ? .orange : .primary)
                        }
                        HStack(spacing: 10) {
                            Label("\(metrics.choresDone)", systemImage: "checklist")
                                .fixedSize()
                            Label("$\(String(format: "%.0f", metrics.totalSpent))", systemImage: "dollarsign.circle")
                                .fixedSize()
                            if let last = metrics.lastPostAt {
                                Label(compactTimeAgo(last), systemImage: "clock")
                                    .fixedSize()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    Spacer()

                    if isSlacking {
                        Text("😴 Slacking")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedDetail
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isCurrentUser ? Color.orange.opacity(0.08) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isCurrentUser ? Color.orange.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Expanded Detail

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.horizontal, 12)
            HStack(spacing: 0) {
                detailStat(
                    emoji: "🧹",
                    value: "\(metrics.choresDone)",
                    label: "chores done"
                )
                detailStat(
                    emoji: "💸",
                    value: "$\(String(format: "%.2f", metrics.totalSpent))",
                    label: "total spent"
                )
                detailStat(
                    emoji: "📅",
                    value: lastPostLabel,
                    label: "last activity"
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func detailStat(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(emoji)
                .font(.title3)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var lastPostLabel: String {
        guard let date = metrics.lastPostAt else { return "never" }
        let days = Int(Date().timeIntervalSince(date) / 86400)
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        return "\(days) days ago"
    }

    private func compactTimeAgo(_ date: Date) -> String {
        let hours = Int(Date().timeIntervalSince(date) / 3600)
        if hours < 1 { return "just now" }
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
