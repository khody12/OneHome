import Foundation
@testable import OneHome

// MARK: - MockAuthService
//
// Controls AuthService behavior in tests. Lets tests simulate successful
// login, sign-up, and failure paths without any network calls.

final class MockAuthService: AuthServiceProtocol {

    // MARK: Call Tracking

    var signUpCallCount = 0
    var lastSignUpEmail: String?
    var lastSignUpUsername: String?
    var lastSignUpName: String?

    var signInCallCount = 0
    var lastSignInEmail: String?

    var signOutCallCount = 0

    var currentUserCallCount = 0

    // MARK: Configurable Return Values

    /// User returned by signUp and currentUser
    var userToReturn: User? = Fake.user()

    /// If set, all calls throw this error (simulates network/auth failures)
    var errorToThrow: Error?

    // MARK: - AuthServiceProtocol

    func signUp(email: String, password: String, username: String, name: String) async throws -> User {
        signUpCallCount += 1
        lastSignUpEmail = email
        lastSignUpUsername = username
        lastSignUpName = name
        if let error = errorToThrow { throw error }
        guard let user = userToReturn else { throw AppError.notFound }
        return user
    }

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        lastSignInEmail = email
        if let error = errorToThrow { throw error }
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func currentUser() async throws -> User? {
        currentUserCallCount += 1
        if let error = errorToThrow { throw error }
        return userToReturn
    }

    // MARK: Convenience Reset

    func reset() {
        signUpCallCount = 0
        lastSignUpEmail = nil
        lastSignUpUsername = nil
        lastSignUpName = nil
        signInCallCount = 0
        lastSignInEmail = nil
        signOutCallCount = 0
        currentUserCallCount = 0
        userToReturn = Fake.user()
        errorToThrow = nil
    }
}
