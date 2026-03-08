import Testing
import Foundation
@testable import OneHome

// MARK: - Testable HomeViewModel
//
// Subclass of HomeViewModel that replaces HomeService.shared with an injected mock.
// The production ViewModel calls HomeService.shared directly; we override each
// method to route through the injected service instead.

@Observable
final class TestableHomeViewModel: HomeViewModel {
    let homeService: MockHomeService

    init(homeService: MockHomeService) {
        self.homeService = homeService
    }

    override func loadHomes(for userID: UUID) async {
        isLoading = true
        do {
            homes = try await homeService.fetchHomes(for: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    override func createHome(appState: AppState) async {
        guard !newHomeName.isEmpty, let userID = appState.currentUser?.id else { return }
        isLoading = true
        do {
            let home = try await homeService.createHome(name: newHomeName, ownerID: userID)
            homes.append(home)
            newHomeName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    override func joinHome(appState: AppState) async {
        guard !inviteCode.isEmpty, let userID = appState.currentUser?.id else { return }
        isLoading = true
        do {
            let home = try await homeService.joinHomeByCode(inviteCode, userID: userID)
            homes.append(home)
            inviteCode = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - HomeViewModelTests

@Suite("HomeViewModel")
struct HomeViewModelTests {

    // MARK: Helpers

    private func makeSUT() -> (vm: TestableHomeViewModel, svc: MockHomeService) {
        let svc = MockHomeService()
        let vm = TestableHomeViewModel(homeService: svc)
        return (vm, svc)
    }

    /// Creates an AppState with a fake current user pre-populated.
    /// AppState normally fetches auth on init; we skip that by setting
    /// currentUser directly after construction.
    private func makeAppState(user: User = Fake.user()) -> AppState {
        // AppState fires a Task { await checkAuth() } on init which hits
        // the real AuthService. We accept that side effect because
        // currentUser is set synchronously before any test method runs.
        let state = AppState()
        state.currentUser = user
        state.isAuthenticated = true
        return state
    }

    // MARK: - loadHomes

    @Test("loadHomes populates the homes array")
    func loadHomesPopulatesArray() async {
        // WHY: The HomeView lists all homes a user belongs to.
        // After load, vm.homes must reflect what the service returned.
        let (vm, svc) = makeSUT()
        let home1 = Fake.home(name: "Main Apartment")
        let home2 = Fake.home(name: "Beach House")
        svc.homesToReturn = [home1, home2]

        await vm.loadHomes(for: UUID())

        #expect(vm.homes.count == 2)
        #expect(vm.homes[0].id == home1.id)
        #expect(vm.homes[1].id == home2.id)
    }

    @Test("loadHomes with empty result sets empty array without error")
    func loadHomesEmptyIsOK() async {
        // WHY: A new user has no homes yet. That's valid — no error should appear.
        let (vm, _) = makeSUT()

        await vm.loadHomes(for: UUID())

        #expect(vm.homes.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadHomes sets errorMessage on service failure")
    func loadHomesErrorSetsMessage() async {
        // WHY: Network errors on home load must surface as error messages,
        // not silent empty states.
        let (vm, svc) = makeSUT()
        svc.errorToThrow = AppError.networkError("DNS failure")

        await vm.loadHomes(for: UUID())

        #expect(vm.errorMessage != nil)
        #expect(vm.homes.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("loadHomes passes the correct userID to the service")
    func loadHomesPassesUserID() async {
        // WHY: The service must receive the right userID, otherwise the wrong
        // homes are fetched.
        let (vm, svc) = makeSUT()
        let userID = UUID()

        await vm.loadHomes(for: userID)

        #expect(svc.lastFetchedUserID == userID)
        #expect(svc.fetchHomesCallCount == 1)
    }

    // MARK: - createHome

    @Test("createHome appends new home and clears newHomeName")
    func createHomeAppendsAndClears() async {
        // WHY: After creating a home, it should appear in the list immediately
        // and the text field should be cleared so the user can enter another.
        let (vm, svc) = makeSUT()
        let appState = makeAppState()
        let createdHome = Fake.home(name: "The New Pad", inviteCode: "NEWPAD01")
        svc.createdHomeToReturn = createdHome
        vm.newHomeName = "The New Pad"

        await vm.createHome(appState: appState)

        #expect(vm.homes.count == 1)
        #expect(vm.homes[0].id == createdHome.id)
        #expect(vm.newHomeName == "")  // cleared after success
        #expect(vm.errorMessage == nil)
    }

    @Test("createHome with empty newHomeName does not call service")
    func createHomeEmptyNameSkipsService() async {
        // WHY: An empty home name is invalid. The guard in the VM should
        // catch this and never call the service — no phantom DB rows.
        let (vm, svc) = makeSUT()
        let appState = makeAppState()
        vm.newHomeName = ""

        await vm.createHome(appState: appState)

        #expect(svc.createHomeCallCount == 0)
        #expect(vm.homes.isEmpty)
    }

    @Test("createHome with no current user does not call service")
    func createHomeNoUserSkipsService() async {
        // WHY: If AppState has no logged-in user (e.g. session expired),
        // createHome must bail out without a service call.
        let (vm, svc) = makeSUT()
        let appState = AppState()
        // No currentUser set
        vm.newHomeName = "Some Home"

        await vm.createHome(appState: appState)

        #expect(svc.createHomeCallCount == 0)
        #expect(vm.homes.isEmpty)
    }

    @Test("createHome sets errorMessage on service failure")
    func createHomeErrorSetsMessage() async {
        // WHY: If the Supabase insert fails, the error must be shown to the user.
        let (vm, svc) = makeSUT()
        svc.errorToThrow = AppError.networkError("insert failed")
        let appState = makeAppState()
        vm.newHomeName = "Crash House"

        await vm.createHome(appState: appState)

        #expect(vm.errorMessage != nil)
        #expect(vm.homes.isEmpty)
        #expect(vm.newHomeName == "Crash House")  // NOT cleared on failure
    }

    @Test("createHome passes correct ownerID to service")
    func createHomePassesOwnerID() async {
        // WHY: The home must be owned by the current user, not some default ID.
        let (vm, svc) = makeSUT()
        let user = Fake.user(username: "owner99", name: "Owner User")
        let appState = makeAppState(user: user)
        vm.newHomeName = "Owner's Pad"

        await vm.createHome(appState: appState)

        #expect(svc.lastCreatedOwnerID == user.id)
        #expect(svc.lastCreatedHomeName == "Owner's Pad")
    }

    // MARK: - joinHome

    @Test("joinHome appends the joined home and clears inviteCode")
    func joinHomeAppendsAndClears() async {
        // WHY: After joining, the home appears in the user's list immediately
        // and the invite code field resets for re-use.
        let (vm, svc) = makeSUT()
        let appState = makeAppState()
        let joinedHome = Fake.home(name: "Roomie's Place", inviteCode: "ROOMIE42")
        svc.joinedHomeToReturn = joinedHome
        vm.inviteCode = "ROOMIE42"

        await vm.joinHome(appState: appState)

        #expect(vm.homes.count == 1)
        #expect(vm.homes[0].id == joinedHome.id)
        #expect(vm.inviteCode == "")  // cleared after success
        #expect(vm.errorMessage == nil)
    }

    @Test("joinHome with empty inviteCode does not call service")
    func joinHomeEmptyCodeSkipsService() async {
        // WHY: An empty invite code is meaningless — guard should short-circuit.
        let (vm, svc) = makeSUT()
        let appState = makeAppState()
        vm.inviteCode = ""

        await vm.joinHome(appState: appState)

        #expect(svc.joinHomeCallCount == 0)
        #expect(vm.homes.isEmpty)
    }

    @Test("joinHome with no current user does not call service")
    func joinHomeNoUserSkipsService() async {
        // WHY: Can't join a home without an authenticated user ID.
        let (vm, svc) = makeSUT()
        let appState = AppState()
        vm.inviteCode = "SOMECD01"

        await vm.joinHome(appState: appState)

        #expect(svc.joinHomeCallCount == 0)
    }

    @Test("joinHome sets errorMessage when code is not found")
    func joinHomeNotFoundSetsError() async {
        // WHY: An invalid invite code returns .notFound — this must show
        // a clear error so the user knows to check the code.
        let (vm, svc) = makeSUT()
        svc.errorToThrow = AppError.notFound
        let appState = makeAppState()
        vm.inviteCode = "BADCODE1"

        await vm.joinHome(appState: appState)

        #expect(vm.errorMessage != nil)
        #expect(vm.homes.isEmpty)
        #expect(vm.inviteCode == "BADCODE1")  // NOT cleared on failure
    }

    @Test("joinHome passes the invite code correctly to service")
    func joinHomePassesCode() async {
        // WHY: The service must receive the raw code the user typed.
        // Any transformation (uppercasing) happens in the service, not the VM.
        let (vm, svc) = makeSUT()
        let appState = makeAppState()
        vm.inviteCode = "mycode1"

        await vm.joinHome(appState: appState)

        #expect(svc.lastJoinedCode == "mycode1")
    }
}
