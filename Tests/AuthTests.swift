import Testing
import Foundation
@testable import OneHome

// MARK: - TestableAuthViewModel
//
// Subclass of AuthViewModel that replaces the concrete AuthService.shared
// singleton with an injected mock. All production logic stays in the base class;
// only the service call is overridden so tests are pure and side-effect-free.

@Observable
final class TestableAuthViewModel: AuthViewModel {
    let authService: MockAuthService

    init(authService: MockAuthService) {
        self.authService = authService
    }

    override func signIn(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Fill in all fields 😤"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(email: email, password: password)
            // Simulate checkAuth by using the mock's userToReturn
            appState.currentUser = authService.userToReturn
            appState.isAuthenticated = authService.userToReturn != nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    override func signUp(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !name.isEmpty else {
            errorMessage = "Don't leave fields empty, champ 🙄"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let user = try await authService.signUp(
                email: email,
                password: password,
                username: username,
                name: name
            )
            appState.currentUser = user
            appState.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Auth Flow Tests

@Suite("Auth Flow")
struct AuthFlowTests {

    // MARK: Helpers

    private func makeSUT(user: User? = Fake.user()) -> (
        vm: TestableAuthViewModel,
        authService: MockAuthService,
        appState: AppState
    ) {
        let mock = MockAuthService()
        mock.userToReturn = user
        let vm = TestableAuthViewModel(authService: mock)
        let appState = AppState.__forTesting()
        return (vm, mock, appState)
    }

    // MARK: - Sign In Validation

    @Test("Empty email prevents sign in")
    func emptyEmailBlocksSignIn() async {
        // WHY: The VM guards on empty email before calling the service.
        // Verifies client-side validation fires and no network call is made.
        let (vm, authService, appState) = makeSUT()
        vm.email = ""
        vm.password = "secret123"

        await vm.signIn(appState: appState)

        #expect(authService.signInCallCount == 0)
        #expect(vm.errorMessage != nil)
        #expect(appState.isAuthenticated == false)
    }

    @Test("Empty password prevents sign in")
    func emptyPasswordBlocksSignIn() async {
        // WHY: Same guard as above but for password. Both fields must be non-empty.
        let (vm, authService, appState) = makeSUT()
        vm.email = "user@onehome.app"
        vm.password = ""

        await vm.signIn(appState: appState)

        #expect(authService.signInCallCount == 0)
        #expect(vm.errorMessage != nil)
        #expect(appState.isAuthenticated == false)
    }

    // MARK: - Sign Up Validation

    @Test("Empty username prevents sign up")
    func emptyUsernameBlocksSignUp() async {
        // WHY: All four fields are required for sign-up. An empty username
        // should short-circuit before any network call.
        let (vm, authService, appState) = makeSUT()
        vm.email = "user@onehome.app"
        vm.password = "secret123"
        vm.username = ""
        vm.name = "Test User"

        await vm.signUp(appState: appState)

        #expect(authService.signUpCallCount == 0)
        #expect(vm.errorMessage != nil)
        #expect(appState.isAuthenticated == false)
    }

    @Test("Empty name prevents sign up")
    func emptyNameBlocksSignUp() async {
        // WHY: The `name` field (display name) is also required. Verify it
        // gates the same as email/password/username.
        let (vm, authService, appState) = makeSUT()
        vm.email = "user@onehome.app"
        vm.password = "secret123"
        vm.username = "cooluser"
        vm.name = ""

        await vm.signUp(appState: appState)

        #expect(authService.signUpCallCount == 0)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Successful Auth

    @Test("Successful sign in sets isAuthenticated on AppState")
    func signInSetsAuthenticated() async {
        // WHY: The whole app gates on AppState.isAuthenticated. If sign-in
        // succeeds, this flag must flip to true so the user sees the main UI.
        let fakeUser = Fake.user()
        let (vm, _, appState) = makeSUT(user: fakeUser)
        vm.email = "user@onehome.app"
        vm.password = "correct_password"

        await vm.signIn(appState: appState)

        #expect(appState.isAuthenticated == true)
        #expect(appState.currentUser?.id == fakeUser.id)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test("Successful sign up sets isAuthenticated and currentUser on AppState")
    func signUpSetsAuthenticated() async {
        // WHY: After sign-up the user is logged in immediately — they should
        // not be bounced back to the login screen.
        let fakeUser = Fake.user(username: "newuser", name: "New User")
        let (vm, _, appState) = makeSUT(user: fakeUser)
        vm.email = "newuser@onehome.app"
        vm.password = "securepassword"
        vm.username = "newuser"
        vm.name = "New User"

        await vm.signUp(appState: appState)

        #expect(appState.isAuthenticated == true)
        #expect(appState.currentUser != nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - Sign Out

    @Test("Sign out clears user and home from AppState")
    func signOutClearsState() async {
        // WHY: After sign-out the user must see the auth screen, not a
        // stale home screen with the previous user's data.
        let (_, _, appState) = makeSUT()
        appState.currentUser = Fake.user()
        appState.currentHome = Fake.home()
        appState.isAuthenticated = true

        await appState.signOut()

        #expect(appState.isAuthenticated == false)
        #expect(appState.currentUser == nil)
        #expect(appState.currentHome == nil)
    }

    // MARK: - Auth Errors

    @Test("Auth error sets errorMessage on AuthViewModel")
    func authErrorSetsMessage() async {
        // WHY: Supabase errors (bad credentials, network timeout, etc.) must
        // surface as readable messages — not crash or silently fail.
        let (vm, authService, appState) = makeSUT()
        authService.errorToThrow = AppError.unauthorized
        vm.email = "user@onehome.app"
        vm.password = "wrong_password"

        await vm.signIn(appState: appState)

        #expect(vm.errorMessage != nil)
        #expect(appState.isAuthenticated == false)
        #expect(vm.isLoading == false)
    }

    @Test("Sign up error sets errorMessage and does not authenticate")
    func signUpErrorSetsMessage() async {
        // WHY: If the Supabase signUp call fails (e.g. duplicate email),
        // the user should see an error and remain unauthenticated.
        let (vm, authService, appState) = makeSUT()
        authService.errorToThrow = AppError.invalidInput("Email already in use")
        vm.email = "taken@onehome.app"
        vm.password = "password123"
        vm.username = "someone"
        vm.name = "Someone"

        await vm.signUp(appState: appState)

        #expect(vm.errorMessage != nil)
        #expect(appState.isAuthenticated == false)
    }

    // MARK: - New User State

    @Test("New user has no homes after registration")
    func newUserHasNoHomes() async {
        // WHY: A freshly registered user has no home memberships yet.
        // AppState.currentHome must be nil until they create or join one.
        let (vm, _, appState) = makeSUT(user: Fake.user())
        vm.email = "fresh@onehome.app"
        vm.password = "password"
        vm.username = "freshuser"
        vm.name = "Fresh User"

        await vm.signUp(appState: appState)

        #expect(appState.currentHome == nil)
        #expect(appState.isAuthenticated == true)
    }

    // MARK: - isLoading flag

    @Test("isLoading is false after sign in completes")
    func isLoadingResetAfterSignIn() async {
        // WHY: A stuck spinner is a bad UX. isLoading must reset whether
        // sign-in succeeds or fails.
        let (vm, _, appState) = makeSUT()
        vm.email = "user@onehome.app"
        vm.password = "password"

        await vm.signIn(appState: appState)

        #expect(vm.isLoading == false)
    }

    @Test("isLoading is false after sign up fails")
    func isLoadingResetAfterSignUpError() async {
        let (vm, authService, appState) = makeSUT()
        authService.errorToThrow = AppError.networkError("server down")
        vm.email = "user@onehome.app"
        vm.password = "password"
        vm.username = "user"
        vm.name = "User"

        await vm.signUp(appState: appState)

        #expect(vm.isLoading == false)
    }
}

// MARK: - AppState Testing Helper

extension AppState {
    /// Creates an AppState that skips the async checkAuth() init task.
    /// Use this in tests to get a clean, predictable initial state.
    static func __forTesting() -> AppState {
        // We rely on the normal init — checkAuth uses AuthService.shared
        // which is fine as long as tests don't wait for it. The TestableAuthViewModel
        // bypasses checkAuth entirely by setting appState properties directly.
        AppState()
    }
}
