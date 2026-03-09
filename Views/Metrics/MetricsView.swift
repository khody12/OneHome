import SwiftUI
import Charts

struct MetricsView: View {
    let home: Home
    let currentUserID: UUID

    @State private var vm = MetricsViewModel()
    @State private var activeTab: MetricsTab = .stats

    enum MetricsTab: String, CaseIterable, Identifiable {
        case stats = "Stats"
        case leaderboard = "Leaderboard"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Crunching the numbers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.metrics.isEmpty && activeTab == .stats {
                    VStack(spacing: 16) {
                        Text("🤷")
                            .font(.system(size: 60))
                        Text("No stats yet. Get to work!")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // Internal tab picker
                        Picker("View", selection: $activeTab) {
                            ForEach(MetricsTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        if activeTab == .stats {
                            statsContent
                        } else {
                            leaderboardContent
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard 🏆")
            .task { await vm.load(for: home, currentUserID: currentUserID) }
            .refreshable { await vm.load(for: home, currentUserID: currentUserID) }
        }
    }

    // MARK: - Stats Tab

    private var statsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                homeHeaderSection
                currentUserCard
                chartSection
                classicLeaderboardSection
                if !vm.slackers.isEmpty {
                    HallOfShameView(slackers: vm.slackers, allMetrics: vm.metrics)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Leaderboard Tab

    private var leaderboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Type picker
                Picker("Board", selection: $vm.selectedLeaderboard) {
                    ForEach(LeaderboardType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Time range toggle
                HStack(spacing: 0) {
                    ForEach(TimeRange.allCases) { range in
                        Button {
                            vm.selectedTimeRange = range
                            Task { await vm.load(for: home, currentUserID: currentUserID) }
                        } label: {
                            Text(range.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(vm.selectedTimeRange == range ? .white : .orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(
                                    vm.selectedTimeRange == range
                                        ? Color.orange
                                        : Color.orange.opacity(0.1),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Chore subcategory picker
                if vm.selectedLeaderboard == .chores {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            choreSubChip(label: "All Chores", emoji: "🧹", sub: nil)
                            ForEach(ChoreSubcategory.allCases.filter { $0 != .other }) { sub in
                                choreSubChip(label: sub.label, emoji: sub.emoji, sub: sub)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Leaderboard rows
                categoryLeaderboardSection

                if vm.activeLeaderboardEntries.isEmpty {
                    VStack(spacing: 12) {
                        Text("📭")
                            .font(.system(size: 48))
                        Text("No data yet for this board")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
            .animation(.easeInOut(duration: 0.22), value: vm.selectedLeaderboard)
            .animation(.easeInOut(duration: 0.22), value: vm.selectedChoreSubcategory)
        }
    }

    private func choreSubChip(label: String, emoji: String, sub: ChoreSubcategory?) -> some View {
        let isSelected = vm.selectedChoreSubcategory == sub
        return Button {
            vm.selectedChoreSubcategory = sub
        } label: {
            HStack(spacing: 5) {
                Text(emoji)
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.orange : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var categoryLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(boardTitle)
                .font(.headline)
                .padding(.horizontal)

            ForEach(Array(vm.activeLeaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                categoryLeaderboardRow(rank: index + 1, entry: entry)
                    .padding(.horizontal)
            }
        }
    }

    private var boardTitle: String {
        switch vm.selectedLeaderboard {
        case .overall: return "Overall Chores"
        case .chores:
            if let sub = vm.selectedChoreSubcategory {
                return "\(sub.emoji) \(sub.label)"
            }
            return "All Chores"
        case .spending: return "Top Spenders 💸"
        }
    }

    private func categoryLeaderboardRow(rank: Int, entry: CategoryLeaderboardEntry) -> some View {
        let isCurrentUser = entry.id == currentUserID
        return HStack(spacing: 12) {
            Text(rankEmoji(for: rank))
                .font(.title3)
                .frame(width: 36)

            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.orange : Color.orange.opacity(0.25))
                    .frame(width: 38, height: 38)
                Text(String(entry.user.name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(isCurrentUser ? .white : .orange)
            }

            Text(entry.user.name)
                .font(.headline)
                .foregroundStyle(isCurrentUser ? .orange : .primary)

            Spacer()

            categoryScoreBadge(entry: entry)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isCurrentUser ? Color.orange.opacity(0.08) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isCurrentUser ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func categoryScoreBadge(entry: CategoryLeaderboardEntry) -> some View {
        switch vm.selectedLeaderboard {
        case .overall, .chores:
            Text("\(entry.count) chore\(entry.count == 1 ? "" : "s")")
                .font(.subheadline.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12), in: Capsule())
                .foregroundStyle(.orange)
        case .spending:
            Text("$\(String(format: "%.0f", entry.totalAmount))")
                .font(.subheadline.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.green)
        }
    }

    private func rankEmoji(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }

    // MARK: - Header (Stats tab)

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

    // MARK: - Current User Card (Stats tab)

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

    // MARK: - Chart (Stats tab)

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

    // MARK: - Classic Rankings (Stats tab)

    private var classicLeaderboardSection: some View {
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
