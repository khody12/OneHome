import SwiftUI

@Observable
class InviteViewModel {
    var pendingInvites: [PendingInvite] = []
    var contactsOnOneHome: [User] = []
    var usernameToInvite = ""
    var isLoading = false
    var errorMessage: String?
    var contactsPermissionDenied = false
    var showInviteSuccessToast = false

    func loadPendingInvites(for userID: UUID) async {
        isLoading = true
        do {
            pendingInvites = try await InviteService.shared.fetchPendingInvites(for: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Requests contacts permission, then finds which contacts are on OneHome
    func loadContacts() async {
        let granted = await ContactsService.shared.requestPermission()
        guard granted else {
            contactsPermissionDenied = true
            return
        }
        contactsPermissionDenied = false
        isLoading = true
        do {
            let emails = try await ContactsService.shared.fetchContactEmails()
            contactsOnOneHome = try await ContactsService.shared.findOneHomeUsers(from: emails)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func inviteByUsername(to home: Home, from userID: UUID) async {
        let trimmed = usernameToInvite.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await InviteService.shared.inviteByUsername(trimmed, to: home.id, from: userID)
            usernameToInvite = ""
            showInviteSuccessToast = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func inviteContact(_ contact: User, to home: Home, from userID: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            try await InviteService.shared.inviteByUsername(contact.username, to: home.id, from: userID)
            showInviteSuccessToast = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func accept(_ invite: PendingInvite, userID: UUID, appState: AppState) async {
        isLoading = true
        do {
            try await InviteService.shared.accept(invite: invite, userID: userID)
            pendingInvites.removeAll { $0.id == invite.id }
            // Navigate into the accepted home
            if let home = invite.home {
                appState.currentHome = home
            }
            appState.pendingInviteCount = pendingInvites.count
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func decline(_ invite: PendingInvite) async {
        isLoading = true
        do {
            try await InviteService.shared.decline(invite: invite)
            pendingInvites.removeAll { $0.id == invite.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
