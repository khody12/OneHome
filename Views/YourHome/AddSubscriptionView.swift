import SwiftUI

// MARK: - Popular Services Data

struct PopularService: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

let popularServices: [PopularService] = [
    PopularService(name: "Netflix", icon: "📺"),
    PopularService(name: "Spotify", icon: "🎵"),
    PopularService(name: "HBO Max", icon: "🎬"),
    PopularService(name: "Disney+", icon: "🏰"),
    PopularService(name: "Hulu", icon: "📡"),
    PopularService(name: "Apple TV+", icon: "🍎"),
    PopularService(name: "Amazon Prime", icon: "📦"),
    PopularService(name: "YouTube Premium", icon: "▶️"),
    PopularService(name: "Apple Music", icon: "🎶"),
    PopularService(name: "Peacock", icon: "🦚"),
    PopularService(name: "Paramount+", icon: "⭐"),
    PopularService(name: "ESPN+", icon: "🏈"),
    PopularService(name: "Xbox Game Pass", icon: "🎮"),
    PopularService(name: "PlayStation Plus", icon: "🎮"),
    PopularService(name: "Nintendo Switch Online", icon: "🎮"),
    PopularService(name: "iCloud+", icon: "☁️"),
    PopularService(name: "Google One", icon: "☁️"),
    PopularService(name: "Dropbox", icon: "📁"),
    PopularService(name: "ChatGPT Plus", icon: "🤖"),
    PopularService(name: "Adobe Creative Cloud", icon: "🎨"),
]

// MARK: - AddSubscriptionView

struct AddSubscriptionView: View {
    let vm: YourHomeViewModel
    let home: Home
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var step: Int = 1
    @State private var selectedService: PopularService? = nil
    @State private var isCustom = false
    @State private var searchText = ""

    // Step 2 fields
    @State private var serviceName = ""
    @State private var serviceIcon = "📱"
    @State private var monthlyCost: Double = 0
    @State private var billingDay: Int = 1
    @State private var selectedMemberIDs: Set<UUID> = []

    private var filteredServices: [PopularService] {
        if searchText.isEmpty { return popularServices }
        return popularServices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if step == 1 {
                    servicePickerStep
                } else {
                    configureStep
                }
            }
            .navigationTitle(step == 1 ? "Pick a Service" : "Configure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if step == 2 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") { step = 1 }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Service Picker

    private var servicePickerStep: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search services...", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Custom option at top
                    Button {
                        isCustom = true
                        serviceName = ""
                        serviceIcon = "📱"
                        step = 2
                    } label: {
                        HStack {
                            Text("🔧")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading) {
                                Text("Custom")
                                    .font(.subheadline.bold())
                                Text("Add anything not listed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Grid of popular services
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredServices) { service in
                            Button {
                                isCustom = false
                                selectedService = service
                                serviceName = service.name
                                serviceIcon = service.icon
                                // Pre-select all members
                                selectedMemberIDs = Set(vm.members.map { $0.id })
                                step = 2
                            } label: {
                                VStack(spacing: 8) {
                                    Text(service.icon)
                                        .font(.largeTitle)
                                        .frame(width: 56, height: 56)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(service.name)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Step 2: Configure

    private var configureStep: some View {
        Form {
            Section("Service Details") {
                HStack {
                    Text("Icon")
                    Spacer()
                    TextField("emoji", text: $serviceIcon)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Service name", text: $serviceName)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Billing") {
                HStack {
                    Text("Monthly cost")
                    Spacer()
                    TextField("$0.00", value: $monthlyCost, format: .currency(code: "USD"))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
                Picker("Billing day", selection: $billingDay) {
                    ForEach(1...28, id: \.self) { day in
                        Text("Day \(day)").tag(day)
                    }
                }
            }

            Section {
                HStack {
                    Text("Members")
                    Spacer()
                    Button("Select All") {
                        selectedMemberIDs = Set(vm.members.map { $0.id })
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                ForEach(vm.members) { member in
                    Button {
                        if selectedMemberIDs.contains(member.id) {
                            selectedMemberIDs.remove(member.id)
                        } else {
                            selectedMemberIDs.insert(member.id)
                        }
                    } label: {
                        HStack {
                            AvatarCircle(user: member, size: 32)
                            VStack(alignment: .leading) {
                                Text(member.name)
                                    .font(.subheadline)
                                Text("@\(member.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedMemberIDs.contains(member.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Who's on this? (\(selectedMemberIDs.count) selected)")
            } footer: {
                if !selectedMemberIDs.isEmpty && monthlyCost > 0 {
                    let perPerson = (monthlyCost / Double(selectedMemberIDs.count) * 100).rounded() / 100
                    Text("Each person pays \(perPerson, format: .currency(code: "USD"))/month")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Add Subscription ✅")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(canSubmit ? Color.orange : Color.gray.opacity(0.4))
                .disabled(!canSubmit)
            }
        }
    }

    private var canSubmit: Bool {
        !serviceName.trimmingCharacters(in: .whitespaces).isEmpty
        && monthlyCost > 0
        && !selectedMemberIDs.isEmpty
    }

    private func submit() async {
        guard let userID = appState.currentUser?.id else { return }

        // Build placeholder members — the VM will refresh after creation
        let memberList = selectedMemberIDs.map { uid in
            SubscriptionMember(
                id: UUID(),
                subscriptionID: UUID(),
                userID: uid,
                user: vm.members.first { $0.id == uid }
            )
        }

        let sub = Subscription(
            id: UUID(),
            homeID: home.id,
            createdByID: userID,
            serviceName: serviceName.trimmingCharacters(in: .whitespaces),
            serviceIcon: serviceIcon,
            monthlyCost: monthlyCost,
            billingDay: billingDay,
            members: memberList,
            createdAt: Date()
        )

        await vm.addSubscription(sub, memberIDs: Array(selectedMemberIDs))
        dismiss()
    }
}
