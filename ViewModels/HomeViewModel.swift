import SwiftUI

@Observable
class HomeViewModel {
    var homes: [Home] = []
    var isLoading = false
    var errorMessage: String?
    var inviteCode = ""
    var newHomeName = ""

    func loadHomes(for userID: UUID) async {
#if DEBUG
        if userID == DevPreview.user.id {
            homes = [DevPreview.home]
            return
        }
#endif
        isLoading = true
        do {
            homes = try await HomeService.shared.fetchHomes(for: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createHome(appState: AppState) async {
        guard !newHomeName.isEmpty, let userID = appState.currentUser?.id else { return }
        isLoading = true
        do {
            let home = try await HomeService.shared.createHome(name: newHomeName, ownerID: userID)
            homes.append(home)
            newHomeName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func joinHome(appState: AppState) async {
        guard !inviteCode.isEmpty, let userID = appState.currentUser?.id else { return }
        isLoading = true
        do {
            let home = try await HomeService.shared.joinHomeByCode(inviteCode, userID: userID)
            homes.append(home)
            inviteCode = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
