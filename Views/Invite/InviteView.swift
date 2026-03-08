import SwiftUI

struct InviteView: View {
    @Bindable var vm: InviteViewModel
    let home: Home
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Invite by username
                Section {
                    TextField("Enter username...", text: $vm.usernameToInvite)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        Task {
                            if let userID = appState.currentUser?.id {
                                await vm.inviteByUsername(to: home, from: userID)
                            }
                        }
                    } label: {
                        HStack {
                            if vm.isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Send Invite 📨")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(vm.usernameToInvite.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)

                    if let errorMessage = vm.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                } header: {
                    Text("Invite by Username")
                } footer: {
                    Text("They'll see your invite next time they open the app 📬")
                }

                // MARK: - Section 2: From contacts
                Section {
                    if vm.contactsPermissionDenied {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contacts access denied — allow it in Settings to find friends 🙏")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .tint(.orange)
                        }
                        .padding(.vertical, 4)
                    } else if vm.contactsOnOneHome.isEmpty && !vm.isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Load Contacts") {
                                Task { await vm.loadContacts() }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else if vm.isLoading {
                        HStack {
                            ProgressView()
                            Text("Finding friends...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(vm.contactsOnOneHome) { contact in
                            ContactRowView(contact: contact, home: home, vm: vm)
                        }
                    }
                } header: {
                    Text("From Your Contacts")
                } footer: {
                    if !vm.contactsOnOneHome.isEmpty {
                        Text("These contacts already have OneHome accounts ✨")
                    } else if !vm.contactsPermissionDenied && vm.contactsOnOneHome.isEmpty && !vm.isLoading {
                        Text("None of your contacts are on OneHome yet 😢 Be the trendsetter!")
                    }
                }
            }
            .navigationTitle("Invite to \(home.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if vm.showInviteSuccessToast {
                    ToastView(message: "Invite sent! They'll see it next time they open the app 📬")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { vm.showInviteSuccessToast = false }
                            }
                        }
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut, value: vm.showInviteSuccessToast)
        }
    }
}

// MARK: - Contact Row

private struct ContactRowView: View {
    let contact: User
    let home: Home
    @Bindable var vm: InviteViewModel
    @Environment(AppState.self) var appState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.headline)
                Text("@\(contact.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Invite") {
                Task {
                    if let userID = appState.currentUser?.id {
                        await vm.inviteContact(contact, to: home, from: userID)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .font(.caption)
            .disabled(vm.isLoading)
        }
    }
}

// MARK: - Toast

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.orange, in: Capsule())
            .shadow(radius: 4)
    }
}
