import SwiftUI

struct PendingInvitesView: View {
    @Bindable var vm: InviteViewModel
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Loading invites...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.pendingInvites.isEmpty {
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 60))
                        Text("No pending invites")
                            .font(.title2.bold())
                        Text("You're all caught up!")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(vm.pendingInvites) { invite in
                        InviteRowView(invite: invite, vm: vm)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pending Invites 📬")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
}

private struct InviteRowView: View {
    let invite: PendingInvite
    @Bindable var vm: InviteViewModel
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(inviteMessage)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let createdAt = formattedDate {
                    Text(createdAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        if let userID = appState.currentUser?.id {
                            await vm.accept(invite, userID: userID, appState: appState)
                        }
                    }
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(role: .destructive) {
                    Task {
                        await vm.decline(invite)
                    }
                } label: {
                    Label("Decline", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var inviteMessage: String {
        let homeName = invite.home?.name ?? "a home"
        let inviterName = invite.inviter.map { "@\($0.username)" } ?? "Someone"
        return "\(inviterName) invited you to \(homeName) 🏠"
    }

    private var formattedDate: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: invite.createdAt, relativeTo: Date())
    }
}
