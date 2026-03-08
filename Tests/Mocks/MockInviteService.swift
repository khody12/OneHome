import Foundation
@testable import OneHome

// MARK: - InviteServiceProtocol
//
// Protocol mirroring InviteService's public interface.
// Ready for injection into InviteViewModel tests once the ViewModel
// is refactored to accept an injected invite dependency.

protocol InviteServiceProtocol {
    /// Invite a user by username to a home (owner only).
    func inviteByUsername(_ username: String, to homeID: UUID, from inviterID: UUID) async throws
    /// Fetch all pending invites for the given user.
    func fetchPendingInvites(for userID: UUID) async throws -> [PendingInvite]
    /// Accept an invite — joins the home and marks the invite accepted.
    func accept(invite: PendingInvite, userID: UUID) async throws
    /// Decline an invite — marks it declined without joining the home.
    func decline(invite: PendingInvite) async throws
}

// MARK: - MockInviteService
//
// A fully controllable stand-in for InviteService.
// Tests configure invitesToReturn / errorToThrow before calling the method,
// then inspect call counts and captured parameters to verify correct behavior.

final class MockInviteService: InviteServiceProtocol {

    // MARK: Call Tracking

    /// Number of times inviteByUsername was called
    var inviteCallCount = 0
    /// Number of times fetchPendingInvites was called
    var fetchCallCount = 0
    /// Number of times accept was called
    var acceptCallCount = 0
    /// Number of times decline was called
    var declineCallCount = 0

    /// The username passed on the most recent inviteByUsername call
    var lastInvitedUsername: String?
    /// The homeID passed on the most recent inviteByUsername call
    var lastInvitedHomeID: UUID?
    /// The inviterID passed on the most recent inviteByUsername call
    var lastInviterID: UUID?

    /// The userID passed on the most recent fetchPendingInvites call
    var lastFetchedUserID: UUID?

    /// The invite passed on the most recent accept call
    var lastAcceptedInvite: PendingInvite?
    /// The userID passed on the most recent accept call
    var lastAcceptedUserID: UUID?

    /// The invite passed on the most recent decline call
    var lastDeclinedInvite: PendingInvite?

    // MARK: Configurable Return Values

    /// Invites returned by fetchPendingInvites
    var invitesToReturn: [PendingInvite] = []

    /// If set, all calls throw this error (simulates service failures)
    var errorToThrow: Error?

    // MARK: - InviteServiceProtocol

    func inviteByUsername(_ username: String, to homeID: UUID, from inviterID: UUID) async throws {
        inviteCallCount += 1
        lastInvitedUsername = username
        lastInvitedHomeID = homeID
        lastInviterID = inviterID
        if let error = errorToThrow { throw error }
    }

    func fetchPendingInvites(for userID: UUID) async throws -> [PendingInvite] {
        fetchCallCount += 1
        lastFetchedUserID = userID
        if let error = errorToThrow { throw error }
        return invitesToReturn
    }

    func accept(invite: PendingInvite, userID: UUID) async throws {
        acceptCallCount += 1
        lastAcceptedInvite = invite
        lastAcceptedUserID = userID
        if let error = errorToThrow { throw error }
    }

    func decline(invite: PendingInvite) async throws {
        declineCallCount += 1
        lastDeclinedInvite = invite
        if let error = errorToThrow { throw error }
    }

    // MARK: Convenience Reset

    /// Reset all tracking state between tests
    func reset() {
        inviteCallCount = 0
        fetchCallCount = 0
        acceptCallCount = 0
        declineCallCount = 0
        lastInvitedUsername = nil
        lastInvitedHomeID = nil
        lastInviterID = nil
        lastFetchedUserID = nil
        lastAcceptedInvite = nil
        lastAcceptedUserID = nil
        lastDeclinedInvite = nil
        invitesToReturn = []
        errorToThrow = nil
    }
}
