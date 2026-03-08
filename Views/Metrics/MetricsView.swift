import SwiftUI
import Charts

struct MetricsView: View {
    let home: Home
    let currentUserID: UUID

    @State private var vm = MetricsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Crunching the numbers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.metrics.isEmpty {
                    VStack(spacing: 16) {
                        Text("🤷")
                            .font(.system(size: 60))
                        Text("No stats yet. Get to work!")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            homeHeaderSection
                            currentUserCard
                            chartSection
                            leaderboardSection
                            if !vm.slackers.isEmpty {
                                HallOfShameView(slackers: vm.slackers, allMetrics: vm.metrics)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Leaderboard 🏆")
            .task { await vm.load(for: home, currentUserID: currentUserID) }
            .refreshable { await vm.load(for: home, currentUserID: currentUserID) }
        }
    }

    // MARK: - Header

    private var homeHeaderSection: some View {
        VStack(spacing: 6) {
            Text(home.name)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(vm.totalChoresDone)")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.orange)
                    Text("🧹 chores done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("$\(String(format: "%.0f", vm.totalSpent))")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.orange)
                    Text("💸 total spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Current User Card

    @ViewBuilder
    private var currentUserCard: some View {
        if let mine = vm.currentUserMetrics {
            let rank = vm.currentUserRank(userID: currentUserID)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your Stats")
                        .font(.headline)
                    Spacer()
                    Text(medalEmoji(for: rank))
                        .font(.title2)
                    Text("Rank #\(rank)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                Divider()
                HStack(spacing: 20) {
                    statPill(value: "\(mine.choresDone)", label: "chores", emoji: "🧹")
                    statPill(value: "$\(String(format: "%.0f", mine.totalSpent))", label: "spent", emoji: "💸")
                    if let last = mine.lastPostAt {
                        statPill(value: timeAgo(last), label: "last post", emoji: "🕐")
                    } else {
                        statPill(value: "never", label: "last post", emoji: "👻")
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
            )
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chores Breakdown")
                .font(.headline)
            Chart(vm.ranked, id: \.id) { m in
                BarMark(
                    x: .value("Chores", m.choresDone),
                    y: .value("Name", m.user?.name ?? "Unknown")
                )
                .foregroundStyle(
                    m.userID == currentUserID ? Color.orange : Color.orange.opacity(0.45)
                )
                .annotation(position: .trailing) {
                    Text("\(m.choresDone)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(vm.ranked.count) * 44 + 16)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rankings")
                .font(.headline)
                .padding(.bottom, 2)
            ForEach(Array(vm.ranked.enumerated()), id: \.element.id) { index, m in
                UserMetricsRowView(
                    rank: index + 1,
                    metrics: m,
                    allMetrics: vm.metrics,
                    isCurrentUser: m.userID == currentUserID
                )
            }
        }
    }

    // MARK: - Helpers

    private func statPill(value: String, label: String, emoji: String) -> some View {
        VStack(spacing: 2) {
            Text("\(emoji) \(value)")
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func medalEmoji(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "💀"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let hours = Int(Date().timeIntervalSince(date) / 3600)
        if hours < 1 { return "just now" }
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
