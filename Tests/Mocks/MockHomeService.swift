import Foundation
@testable import OneHome

// MARK: - MockHomeService
//
// Controls all HomeService behavior in tests. Configure `homesToReturn`
// for fetch results and `createdHomeToReturn` / `joinedHomeToReturn`
// for mutation outcomes.

final class MockHomeService: HomeServiceProtocol {

    // MARK: Call Tracking

    var fetchHomesCallCount = 0
    var lastFetchedUserID: UUID?

    var createHomeCallCount = 0
    var lastCreatedHomeName: String?
    var lastCreatedOwnerID: UUID?

    var joinHomeCallCount = 0
    var lastJoinedCode: String?
    var lastJoinedUserID: UUID?

    var fetchMembersCallCount = 0
    var lastFetchedMembersHomeID: UUID?

    // MARK: Configurable Return Values

    /// Homes returned by fetchHomes
    var homesToReturn: [Home] = []

    /// Home returned by createHome
    var createdHomeToReturn: Home = Fake.home(name: "New Home", inviteCode: "NEWH0ME")

    /// Home returned by joinHomeByCode
    var joinedHomeToReturn: Home = Fake.home(name: "Joined Home", inviteCode: "JOINCODE")

    /// Members returned by fetchMembers
    var membersToReturn: [User] = []

    /// If set, all calls throw this error
    var errorToThrow: Error?

    // MARK: - HomeServiceProtocol

    func fetchHomes(for userID: UUID) async throws -> [Home] {
        fetchHomesCallCount += 1
        lastFetchedUserID = userID
        if let error = errorToThrow { throw error }
        return homesToReturn
    }

    func createHome(name: String, ownerID: UUID) async throws -> Home {
        createHomeCallCount += 1
        lastCreatedHomeName = name
        lastCreatedOwnerID = ownerID
        if let error = errorToThrow { throw error }
        return createdHomeToReturn
    }

    func joinHomeByCode(_ code: String, userID: UUID) async throws -> Home {
        joinHomeCallCount += 1
        lastJoinedCode = code
        lastJoinedUserID = userID
        if let error = errorToThrow { throw error }
        return joinedHomeToReturn
    }

    func fetchMembers(for homeID: UUID) async throws -> [User] {
        fetchMembersCallCount += 1
        lastFetchedMembersHomeID = homeID
        if let error = errorToThrow { throw error }
        return membersToReturn
    }

    // MARK: Convenience Reset

    func reset() {
        fetchHomesCallCount = 0
        lastFetchedUserID = nil
        createHomeCallCount = 0
        lastCreatedHomeName = nil
        lastCreatedOwnerID = nil
        joinHomeCallCount = 0
        lastJoinedCode = nil
        lastJoinedUserID = nil
        fetchMembersCallCount = 0
        lastFetchedMembersHomeID = nil
        homesToReturn = []
        createdHomeToReturn = Fake.home(name: "New Home", inviteCode: "NEWH0ME")
        joinedHomeToReturn = Fake.home(name: "Joined Home", inviteCode: "JOINCODE")
        membersToReturn = []
        errorToThrow = nil
    }
}
