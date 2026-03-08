import SwiftUI

struct SpendHistoryView: View {
    let vm: YourHomeViewModel
    let currentUserID: UUID
    @Environment(\.dismiss) var dismiss
    @State private var filterCategory: SpendCategory? = nil

    private var filteredLogs: [SpendLog] {
        guard let filter = filterCategory else { return vm.spendLogs }
        return vm.spendLogs.filter { $0.category == filter }
    }

    private var groupedByMonth: [(key: String, logs: [SpendLog])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredLogs) { log -> String in
            let components = calendar.dateComponents([.year, .month], from: log.createdAt)
            let year = components.year ?? 0
            let month = components.month ?? 0
            let date = calendar.date(from: DateComponents(year: year, month: month)) ?? log.createdAt
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        // Sort months newest first
        return grouped
            .map { (key: $0.key, logs: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { group1, group2 in
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                let d1 = formatter.date(from: group1.key) ?? .distantPast
                let d2 = formatter.date(from: group2.key) ?? .distantPast
                return d1 > d2
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Total header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(filteredLogs.reduce(0) { $0 + $1.amount }, format: .currency(code: "USD"))
                            .font(.title2.bold())
                    }
                    Spacer()
                    Text("\(filteredLogs.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(label: "All", isSelected: filterCategory == nil) {
                            filterCategory = nil
                        }
                        ForEach(SpendCategory.allCases, id: \.rawValue) { category in
                            FilterChip(
                                label: category.emoji + " " + category.label,
                                isSelected: filterCategory == category
                            ) {
                                filterCategory = filterCategory == category ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.secondarySystemBackground))

                Divider()

                if filteredLogs.isEmpty {
                    Spacer()
                    Text("No spend logs here yet 💸")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(groupedByMonth, id: \.key) { group in
                            Section(header: Text(group.key).font(.headline)) {
                                ForEach(group.logs) { log in
                                    SpendHistoryRow(log: log)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            if log.userID == currentUserID {
                                                Button(role: .destructive) {
                                                    Task {
                                                        try? await SpendLogService.shared.deleteLog(id: log.id)
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Spend History 🧾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SpendHistoryRow: View {
    let log: SpendLog

    var body: some View {
        HStack(spacing: 12) {
            Text(log.category.emoji)
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.note.isEmpty ? log.category.label : log.note)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if let user = log.user {
                        AvatarCircle(user: user, size: 18)
                        Text(user.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(log.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(log.amount, format: .currency(code: "USD"))
                .font(.subheadline.bold().monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.orange : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
