import SwiftUI
import Charts

struct YourHomeView: View {
    @Environment(AppState.self) var appState
    @State private var vm = YourHomeViewModel()
    @State private var showSwitchHomes = false
    @State private var showLogSpend = false
    @State private var showAddSubscription = false
    @State private var showSpendHistory = false
    @State private var selectedMember: User?

    var home: Home

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    homeHeaderSection
                    roommatesSection
                    spendingOverviewSection
                    recentPurchasesSection
                    subscriptionsSection
                    switchHomesButton
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(home.name)
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.load(home: home) }
            .refreshable { await vm.load(home: home) }
        }
        .sheet(isPresented: $showSwitchHomes) {
            HomeSelectionView()
                .environment(appState)
        }
        .sheet(isPresented: $showLogSpend) {
            LogSpendSheet(vm: vm, home: home)
        }
        .sheet(isPresented: $showAddSubscription) {
            AddSubscriptionView(vm: vm, home: home)
        }
        .sheet(isPresented: $showSpendHistory) {
            SpendHistoryView(vm: vm, currentUserID: appState.currentUser?.id ?? UUID())
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(member: member, vm: vm)
        }
    }

    // MARK: - Home Header

    private var homeHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Invite code row
            Button {
                UIPasteboard.general.string = home.inviteCode
            } label: {
                HStack(spacing: 6) {
                    Text("Invite code: \(home.inviteCode) 📋")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Member avatar row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.members) { member in
                        AvatarCircle(user: member, size: 44)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Roommates Section

    private var roommatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Roommates 👥")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(vm.members) { member in
                        RoommateCard(member: member)
                            .onTapGesture { selectedMember = member }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Spending Overview Section

    private var spendingOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Spending Overview 💸")
                Spacer()
                Button {
                    showLogSpend = true
                } label: {
                    Label("Add Spend", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                .padding(.trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Total this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vm.grandTotal, format: .currency(code: "USD"))
                    .font(.title2.bold())
            }
            .padding(.horizontal)

            if !vm.spendLogs.isEmpty {
                Chart(SpendCategory.allCases, id: \.rawValue) { category in
                    let total = vm.totalByCategory[category] ?? 0
                    if total > 0 {
                        SectorMark(
                            angle: .value("Amount", total),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", category.label))
                        .annotation(position: .overlay) {
                            Text(category.emoji)
                                .font(.caption)
                        }
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)

                // Category breakdown list
                VStack(spacing: 6) {
                    ForEach(SpendCategory.allCases, id: \.rawValue) { category in
                        if let total = vm.totalByCategory[category], total > 0 {
                            HStack {
                                Text(category.emoji + " " + category.label)
                                    .font(.subheadline)
                                Spacer()
                                Text(total, format: .currency(code: "USD"))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            } else {
                Text("No spending logged yet — tap Add Spend to start 💰")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Purchases Section

    private var recentPurchasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Recent Purchases 🧾")
                Spacer()
                Button("See all") {
                    showSpendHistory = true
                }
                .font(.subheadline)
                .foregroundStyle(.orange)
                .padding(.trailing)
            }

            if vm.spendLogs.isEmpty {
                Text("Nothing logged yet 👀")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.spendLogs.prefix(5)) { log in
                        SpendLogRow(log: log)
                        if log.id != vm.spendLogs.prefix(5).last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Subscriptions Section

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Subscriptions 📱")
                Spacer()
                Button {
                    showAddSubscription = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                .padding(.trailing)
            }

            if vm.subscriptions.isEmpty {
                Text("No shared subscriptions yet — add one! 🎬")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.subscriptions) { sub in
                        SubscriptionRowView(subscription: sub)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteSubscription(sub) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        if sub.id != vm.subscriptions.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Switch Homes Button

    private var switchHomesButton: some View {
        Button {
            showSwitchHomes = true
        } label: {
            HStack {
                Spacer()
                Text("Switch Homes 🔄")
                    .font(.subheadline.bold())
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
        .padding(.horizontal)
    }
}

// MARK: - Supporting views

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
    }
}

struct AvatarCircle: View {
    let user: User
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: size, height: size)
            Text(String(user.name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.orange)
        }
    }
}

struct RoommateCard: View {
    let member: User

    var body: some View {
        VStack(spacing: 8) {
            AvatarCircle(user: member, size: 56)
            Text(member.name)
                .font(.caption.bold())
                .lineLimit(1)
            Text("@\(member.username)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SpendLogRow: View {
    let log: SpendLog

    var body: some View {
        HStack(spacing: 12) {
            Text(log.category.emoji)
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.note.isEmpty ? log.category.label : log.note)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(log.user?.name ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(log.amount, format: .currency(code: "USD"))
                    .font(.subheadline.bold().monospacedDigit())
                Text(log.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct MemberDetailSheet: View {
    let member: User
    let vm: YourHomeViewModel
    @Environment(\.dismiss) var dismiss

    var memberTotal: Double {
        vm.spendLogs
            .filter { $0.userID == member.id }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                AvatarCircle(user: member, size: 80)
                    .padding(.top)
                Text(member.name)
                    .font(.title2.bold())
                Text("@\(member.username)")
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    HStack {
                        Label("Total spent here", systemImage: "dollarsign.circle")
                        Spacer()
                        Text(memberTotal, format: .currency(code: "USD"))
                            .bold()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
