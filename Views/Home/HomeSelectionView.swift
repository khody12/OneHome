import SwiftUI

struct HomeSelectionView: View {
    @State private var vm = HomeViewModel()
    @State private var inviteVM = InviteViewModel()
    @Environment(AppState.self) var appState
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var showPendingInvites = false
    @State private var selectedHomeForInvite: Home?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Loading your homes...")
                } else if vm.homes.isEmpty {
                    VStack(spacing: 20) {
                        Text("🏚️ No homes yet!")
                            .font(.title2.bold())
                        Text("Create one or join with an invite code")
                            .foregroundStyle(.secondary)
                        Button("Create a Home 🏗️") { showCreateSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        Button("Join with Code 🔑") { showJoinSheet = true }
                            .buttonStyle(.bordered)
                    }
                } else {
                    List(vm.homes) { home in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                appState.currentHome = home
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(home.name).font(.headline)
                                    Text("Code: \(home.inviteCode)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                selectedHomeForInvite = home
                            } label: {
                                Label("Invite People", systemImage: "person.badge.plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Your Homes 🏠")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Create Home 🏗️") { showCreateSheet = true }
                        Button("Join with Code 🔑") { showJoinSheet = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showPendingInvites = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "envelope.fill")
                            if appState.pendingInviteCount > 0 {
                                Text("\(appState.pendingInviteCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(.red, in: Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .tint(.orange)
                    .accessibilityLabel("Invites \(appState.pendingInviteCount > 0 ? "(\(appState.pendingInviteCount) pending)" : "")")
                }
            }
            .task {
                if let userID = appState.currentUser?.id {
                    await vm.loadHomes(for: userID)
                    await inviteVM.loadPendingInvites(for: userID)
                    appState.pendingInviteCount = inviteVM.pendingInvites.count
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateHomeSheet(vm: vm)
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinHomeSheet(vm: vm)
        }
        .sheet(isPresented: $showPendingInvites) {
            PendingInvitesView(vm: inviteVM)
                .environment(appState)
        }
        .sheet(item: $selectedHomeForInvite) { home in
            InviteView(vm: inviteVM, home: home)
                .environment(appState)
        }
    }
}

struct CreateHomeSheet: View {
    @Bindable var vm: HomeViewModel
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Home name (e.g. The Chateau 🏰)", text: $vm.newHomeName)
            }
            .navigationTitle("Create Home")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await vm.createHome(appState: appState)
                            dismiss()
                        }
                    }
                    .disabled(vm.newHomeName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct JoinHomeSheet: View {
    @Bindable var vm: HomeViewModel
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Invite code", text: $vm.inviteCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
            }
            .navigationTitle("Join a Home")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        Task {
                            await vm.joinHome(appState: appState)
                            dismiss()
                        }
                    }
                    .disabled(vm.inviteCode.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
