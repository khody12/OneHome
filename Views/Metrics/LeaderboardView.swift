import SwiftUI

// MARK: - LeaderboardView
//
// Full leaderboard UI: segmented by Overall / Chores / Spending,
// filterable by All Time / This Month, with subcategory drill-down for Chores.

struct LeaderboardView: View {
    let home: Home
    let currentUserID: UUID

    @State private var vm = MetricsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Crunching the numbers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // ── Type picker ───────────────────────────────
                            Picker("Board", selection: $vm.selectedLeaderboard) {
                                ForEach(LeaderboardType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

                            // ── Time range toggle ─────────────────────────
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

                            // ── Chore subcategory picker ──────────────────
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

                            // ── Leaderboard list ──────────────────────────
                            leaderboardList

                            if vm.activeLeaderboardEntries.isEmpty {
                                emptyState
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .animation(.easeInOut(duration: 0.22), value: vm.selectedLeaderboard)
                        .animation(.easeInOut(duration: 0.22), value: vm.selectedChoreSubcategory)
                    }
                }
            }
            .navigationTitle("Leaderboard 🏆")
            .task { await vm.load(for: home, currentUserID: currentUserID) }
            .refreshable { await vm.load(for: home, currentUserID: currentUserID) }
        }
    }

    // MARK: - Chore subcategory chip

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

    // MARK: - Leaderboard list

    private var leaderboardList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(boardTitle)
                .font(.headline)
                .padding(.horizontal)

            ForEach(Array(vm.activeLeaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                leaderboardRow(rank: index + 1, entry: entry)
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

    private func leaderboardRow(rank: Int, entry: CategoryLeaderboardEntry) -> some View {
        let isCurrentUser = entry.id == currentUserID
        return HStack(spacing: 12) {
            // Rank medal / number
            Text(medalEmoji(for: rank))
                .font(.title3)
                .frame(width: 32)

            // Avatar circle
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.orange : Color.orange.opacity(0.25))
                    .frame(width: 38, height: 38)
                Text(String(entry.user.name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(isCurrentUser ? .white : .orange)
            }

            // Name
            Text(entry.user.name)
                .font(.headline)
                .foregroundStyle(isCurrentUser ? .orange : .primary)

            Spacer()

            // Score badge
            scoreBadge(for: entry)
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
    private func scoreBadge(for entry: CategoryLeaderboardEntry) -> some View {
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📭")
                .font(.system(size: 48))
            Text("No data yet for this board")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    // MARK: - Helpers

    private func medalEmoji(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}
