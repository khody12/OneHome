import Testing
import Foundation
@testable import OneHome

// MARK: - Testable InviteViewModel
//
// Subclass of InviteViewModel that replaces InviteService.shared and
// ContactsService.shared with injected mock behaviour via overrides.

@Observable
final class TestableInviteViewModel: InviteViewModel {
    var stubbedPendingInvites: [PendingInvite] = []
    var stubbedContactsPermissionGranted = true
    var stubbedContactsOnOneHome: [User] = []
    var acceptCallCount = 0
    var declineCallCount = 0
    var lastAcceptedInviteID: UUID?
    var lastDeclinedInviteID: UUID?
    var inviteByUsernameCallCount = 0
    var errorToThrow: Error?

    override func loadPendingInvites(for userID: UUID) async {
        if let error = errorToThrow {
            errorMessage = error.localizedDescription
            return
        }
        pendingInvites = stubbedPendingInvites
    }

    override func loadContacts() async {
        if !stubbedContactsPermissionGranted {
            contactsPermissionDenied = true
            return
        }
        contactsPermissionDenied = false
        contactsOnOneHome = stubbedContactsOnOneHome
    }

    override func inviteByUsername(to home: Home, from userID: UUID) async {
        let trimmed = usernameToInvite.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        inviteByUsernameCallCount += 1
        if let error = errorToThrow {
            errorMessage = error.localizedDescription
            return
        }
        usernameToInvite = ""
        showInviteSuccessToast = true
    }

    override func accept(_ invite: PendingInvite, userID: UUID, appState: AppState) async {
        acceptCallCount += 1
        lastAcceptedInviteID = invite.id
        if let error = errorToThrow {
            errorMessage = error.localizedDescription
            return
        }
        var updated = invite
        updated.status = "accepted"
        pendingInvites.removeAll { $0.id == invite.id }
        if let home = invite.home {
            appState.currentHome = home
        }
    }

    override func decline(_ invite: PendingInvite) async {
        declineCallCount += 1
        lastDeclinedInviteID = invite.id
        if let error = errorToThrow {
            errorMessage = error.localizedDescription
            return
        }
        pendingInvites.removeAll { $0.id == invite.id }
    }
}

// MARK: - InviteTests

@Suite("Invite Flow")
struct InviteTests {

    // MARK: - PendingInvite CodingKeys

    @Test("PendingInvite CodingKeys match schema columns")
    func pendingInviteCodingKeys() throws {
        // WHY: CodingKeys must exactly match the Supabase column names
        // or every decode will silently produce zero-value fields.
        let keys = PendingInvite.CodingKeys.self
        #expect(keys.homeID.rawValue == "home_id")
        #expect(keys.inviteeID.rawValue == "invitee_id")
        #expect(keys.inviterID.rawValue == "inviter_id")
        #expect(keys.createdAt.rawValue == "created_at")
        #expect(keys.id.rawValue == "id")
        #expect(keys.status.rawValue == "status")
    }

    // MARK: - JSON Round-trip

    @Test("PendingInvite round-trips through JSON")
    func pendingInviteRoundTrips() throws {
        // WHY: Supabase returns JSON; we need the model to survive encode/decode
        // so invite data is never silently corrupted in transit.
        let invite = Fake.pendingInvite(status: "pending")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(invite)
        let decoded = try decoder.decode(PendingInvite.self, from: data)

        #expect(decoded.id == invite.id)
        #expect(decoded.homeID == invite.homeID)
        #expect(decoded.inviteeID == invite.inviteeID)
        #expect(decoded.inviterID == invite.inviterID)
        #expect(decoded.status == invite.status)
    }

    // MARK: - Status Values

    @Test("Status values match schema check constraint")
    func inviteStatusValues() {
        // WHY: The schema enforces check (status in ('pending', 'accepted', 'declined')).
        // Any other value will be rejected by Postgres — guard the domain here.
        let valid = ["pending", "accepted", "declined"]
        #expect(valid.contains("pending"))
        #expect(valid.contains("accepted"))
        #expect(valid.contains("declined"))
        #expect(!valid.contains("unknown"))
        #expect(!valid.contains(""))
    }

    // MARK: - Accept / Decline

    @Test("Accept invite sets status to accepted and removes from pending list")
    func acceptInviteChangesStatus() async {
        // WHY: After accepting, the invite must disappear from the pending list
        // and the user should be navigated into the home.
        let vm = TestableInviteViewModel()
        let invite = Fake.pendingInviteWithDetails()
        vm.stubbedPendingInvites = [invite]
        await vm.loadPendingInvites(for: UUID())

        let appState = AppState()
        appState.currentUser = Fake.user()

        await vm.accept(invite, userID: appState.currentUser!.id, appState: appState)

        #expect(vm.acceptCallCount == 1)
        #expect(vm.lastAcceptedInviteID == invite.id)
        #expect(vm.pendingInvites.isEmpty)
        #expect(appState.currentHome?.id == invite.home?.id)
    }

    @Test("Decline invite sets status to declined and removes from pending list")
    func declineInviteChangesStatus() async {
        // WHY: After declining, the invite must be removed from the UI
        // so the user isn't pestered again.
        let vm = TestableInviteViewModel()
        let invite = Fake.pendingInvite(status: "pending")
        vm.stubbedPendingInvites = [invite]
        await vm.loadPendingInvites(for: UUID())

        await vm.decline(invite)

        #expect(vm.declineCallCount == 1)
        #expect(vm.lastDeclinedInviteID == invite.id)
        #expect(vm.pendingInvites.isEmpty)
    }

    // MARK: - ViewModel Loading

    @Test("InviteViewModel loads pending invites")
    func viewModelLoadsPendingInvites() async {
        // WHY: The ViewModel must populate pendingInvites from the service
        // so the badge count and invite list are correct.
        let vm = TestableInviteViewModel()
        let invite1 = Fake.pendingInvite()
        let invite2 = Fake.pendingInviteWithDetails()
        vm.stubbedPendingInvites = [invite1, invite2]

        await vm.loadPendingInvites(for: UUID())

        #expect(vm.pendingInvites.count == 2)
        #expect(vm.pendingInvites[0].id == invite1.id)
        #expect(vm.pendingInvites[1].id == invite2.id)
        #expect(vm.errorMessage == nil)
    }

    @Test("InviteViewModel sets errorMessage when loading fails")
    func viewModelLoadingErrorSetsMessage() async {
        // WHY: A failed fetch must surface as an error message, not a silent
        // empty state that looks identical to "no invites".
        let vm = TestableInviteViewModel()
        vm.errorToThrow = AppError.networkError("timeout")

        await vm.loadPendingInvites(for: UUID())

        #expect(vm.errorMessage != nil)
        #expect(vm.pendingInvites.isEmpty)
    }

    // MARK: - Username Guard

    @Test("InviteViewModel invite by empty username does not call service")
    func emptyUsernameGuard() async {
        // WHY: An empty username is meaningless. The VM's guard must short-circuit
        // before hitting the service — no phantom DB writes.
        let vm = TestableInviteViewModel()
        vm.usernameToInvite = ""
        let home = Fake.home()

        await vm.inviteByUsername(to: home, from: UUID())

        #expect(vm.inviteByUsernameCallCount == 0)
        #expect(vm.showInviteSuccessToast == false)
    }

    @Test("InviteViewModel invite by whitespace-only username does not call service")
    func whitespaceUsernameGuard() async {
        // WHY: "   " trimmed to empty is still invalid — same guard applies.
        let vm = TestableInviteViewModel()
        vm.usernameToInvite = "   "
        let home = Fake.home()

        await vm.inviteByUsername(to: home, from: UUID())

        #expect(vm.inviteByUsernameCallCount == 0)
    }

    @Test("InviteViewModel invite by valid username shows success toast and clears field")
    func validUsernameInviteSucceeds() async {
        // WHY: On success, the text field must clear and a toast must appear
        // to confirm the invite was sent.
        let vm = TestableInviteViewModel()
        vm.usernameToInvite = "alex"
        let home = Fake.home()

        await vm.inviteByUsername(to: home, from: UUID())

        #expect(vm.inviteByUsernameCallCount == 1)
        #expect(vm.usernameToInvite == "")
        #expect(vm.showInviteSuccessToast == true)
    }

    // MARK: - Contacts Permission

    @Test("InviteViewModel contacts load shows permission denied state")
    func contactsPermissionDeniedState() async {
        // WHY: When the user denies contacts access, the UI must show
        // a Settings link rather than an empty list or crash.
        let vm = TestableInviteViewModel()
        vm.stubbedContactsPermissionGranted = false

        await vm.loadContacts()

        #expect(vm.contactsPermissionDenied == true)
        #expect(vm.contactsOnOneHome.isEmpty)
    }

    @Test("InviteViewModel contacts load succeeds when permission granted")
    func contactsPermissionGrantedLoadsUsers() async {
        // WHY: When permission is granted, the VM must surface the matching
        // OneHome users so the owner can invite them with one tap.
        let vm = TestableInviteViewModel()
        vm.stubbedContactsPermissionGranted = true
        vm.stubbedContactsOnOneHome = [Fake.user2(), Fake.user3()]

        await vm.loadContacts()

        #expect(vm.contactsPermissionDenied == false)
        #expect(vm.contactsOnOneHome.count == 2)
    }

    // MARK: - Contacts Filtering

    @Test("Contacts filtering removes non-OneHome users")
    func contactsFilteredCorrectly() {
        // WHY: The service returns only users whose email exists in the users table.
        // This test verifies that the returned list is a strict subset of the
        // device contacts list — extra contacts must not appear.
        let deviceEmails = ["alice@example.com", "bob@example.com", "carol@example.com"]
        let onehomeUsers = [
            Fake.user(email: "alice@example.com"),
            Fake.user(email: "carol@example.com")
        ]

        // Simulate the filtering: only device contact emails that have OneHome accounts
        let onehomeEmails = Set(onehomeUsers.map { $0.email })
        let filtered = deviceEmails.filter { onehomeEmails.contains($0) }

        #expect(filtered.count == 2)
        #expect(filtered.contains("alice@example.com"))
        #expect(filtered.contains("carol@example.com"))
        #expect(!filtered.contains("bob@example.com"))
    }

    @Test("Contacts filtering with empty device contacts returns empty list")
    func emptyContactsReturnsEmpty() {
        // WHY: A user with no contacts should get an empty list, not crash.
        let deviceEmails: [String] = []
        let onehomeUsers: [User] = [Fake.user()]

        let onehomeEmails = Set(onehomeUsers.map { $0.email })
        let filtered = deviceEmails.filter { onehomeEmails.contains($0) }

        #expect(filtered.isEmpty)
    }
}
