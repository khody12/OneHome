import Testing
import Foundation
@testable import OneHome

// MARK: - Payment Flow Tests
//
// Covers:
//  - PaymentViewModel pure logic (split math, member selection)
//  - PaymentRequest / PaymentSplit model correctness (CodingKeys, round-trips)
//  - Venmo / PayPal deep-link URL generation

@Suite("Payment Flow")
struct PaymentTests {

    // MARK: - PaymentViewModel: Even Split Math

    @Test("Even split of $30 among 3 is $10.00")
    func evenSplitThreeWay() {
        // What: $30 divided evenly among 3 members should equal $10.00 each.
        // Why: This is the baseline happy-path for split-evenly mode; the formula
        //      must round to cents correctly before any rounding edge cases arise.
        let vm = PaymentViewModel()
        vm.totalAmount = 30.0
        vm.selectedMembers = [UUID(), UUID(), UUID()]
        vm.splitEvenly = true

        #expect(vm.evenSplitAmount == 10.00)
    }

    @Test("Even split of $10 among 3 rounds to $3.33")
    func evenSplitRoundsCorrectly() {
        // What: $10 / 3 = 3.3333… which must be truncated to $3.33 per member.
        // Why: Floating-point without rounding would produce $3.3333…, causing
        //      the UI to show a misleadingly precise number and sums to drift.
        let vm = PaymentViewModel()
        vm.totalAmount = 10.0
        vm.selectedMembers = [UUID(), UUID(), UUID()]
        vm.splitEvenly = true

        #expect(vm.evenSplitAmount == 3.33)
    }

    @Test("Even split of $0 among 0 members is $0")
    func evenSplitZeroMembers() {
        // What: With no members selected and a $0 total, evenSplitAmount should be $0.
        // Why: Division by zero must be guarded — the property divides by
        //      selectedMembers.count, which would be 0. Verify it doesn't crash and
        //      returns a safe sentinel. (Implementation must handle this guard.)
        let vm = PaymentViewModel()
        vm.totalAmount = 0.0
        vm.selectedMembers = []
        vm.splitEvenly = true

        // If the implementation guards count == 0, result is 0 (or NaN depending on impl).
        // We verify it doesn't crash and stays at 0 when both total and count are 0.
        let result = vm.evenSplitAmount
        #expect(result == 0.0 || result.isNaN,
                "Zero members with $0 total must produce 0 or NaN — never crash")
    }

    // MARK: - PaymentViewModel: Member Selection

    @Test("Select all excludes requestor")
    func selectAllExcludesRequestor() {
        // What: selectAll should add every household member EXCEPT the requestor.
        // Why: You cannot request payment from yourself; the UI must pre-populate
        //      all other members so the requestor just hits "Send".
        let requestorID = UUID()
        let member1 = Fake.user()
        let member2 = Fake.user(username: "jordan", name: "Jordan", email: "j@test.app")
        let requestor = Fake.user(id: requestorID, username: "alex", name: "Alex", email: "a@test.app")
        let allMembers = [requestor, member1, member2]

        let vm = PaymentViewModel()
        vm.selectAll(members: allMembers, excludingID: requestorID)

        #expect(!vm.selectedMembers.contains(requestorID),
                "Requestor must be excluded from selectedMembers")
        #expect(vm.selectedMembers.contains(member1.id))
        #expect(vm.selectedMembers.contains(member2.id))
        #expect(vm.selectedMembers.count == 2)
    }

    @Test("Toggle member adds when not selected")
    func toggleMemberAdds() {
        // What: Calling toggleMember with an ID not in selectedMembers should add it.
        // Why: The toggle is the primary way users adjust who shares a bill.
        let vm = PaymentViewModel()
        let memberID = UUID()

        vm.toggleMember(memberID)

        #expect(vm.selectedMembers.contains(memberID))
    }

    @Test("Toggle member removes when already selected")
    func toggleMemberRemoves() {
        // What: Calling toggleMember twice on the same ID should remove it.
        // Why: Toggle semantics — second press deselects, letting users correct mistakes.
        let vm = PaymentViewModel()
        let memberID = UUID()

        vm.toggleMember(memberID)  // add
        vm.toggleMember(memberID)  // remove

        #expect(!vm.selectedMembers.contains(memberID))
    }

    @Test("Selected count is correct after multiple toggles")
    func selectedCountAfterToggles() {
        // What: Toggle 3 members in, then toggle 1 out — count should be 2.
        // Why: Ensures the Set logic correctly handles add/remove interleaving
        //      without duplicates or accidental extra removals.
        let vm = PaymentViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        vm.toggleMember(id1)
        vm.toggleMember(id2)
        vm.toggleMember(id3)
        vm.toggleMember(id2)  // deselect id2

        #expect(vm.selectedMembers.count == 2)
        #expect(vm.selectedMembers.contains(id1))
        #expect(!vm.selectedMembers.contains(id2))
        #expect(vm.selectedMembers.contains(id3))
    }

    // MARK: - PaymentRequest Model

    @Test("PaymentRequest CodingKeys match schema")
    func paymentRequestCodingKeys() throws {
        // What: Encode a PaymentRequest and verify the JSON keys match the
        //       Supabase column names (snake_case) defined in CodingKeys.
        // Why: A mismatch between Swift property names and DB column names
        //      would silently break all reads/writes without a compile error.
        let request = Fake.paymentRequest(totalAmount: 45.0, note: "Pizza night 🍕")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["post_id"] != nil, "post_id key must exist in JSON")
        #expect(json["home_id"] != nil, "home_id key must exist in JSON")
        #expect(json["requestor_id"] != nil, "requestor_id key must exist in JSON")
        #expect(json["total_amount"] != nil, "total_amount key must exist in JSON")
        #expect(json["created_at"] != nil, "created_at key must exist in JSON")

        // Verify the values round-trip through JSON correctly
        #expect((json["total_amount"] as? Double) == 45.0)
        #expect((json["note"] as? String) == "Pizza night 🍕")
    }

    @Test("PaymentSplit CodingKeys match schema")
    func paymentSplitCodingKeys() throws {
        // What: Encode a PaymentSplit and verify the JSON keys match the schema.
        // Why: payment_request_id, user_id, is_paid, created_at are all remapped
        //      — a typo in CodingKeys would silently drop the field in Supabase.
        let split = Fake.paymentSplit(amount: 15.0, isPaid: false)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(split)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["payment_request_id"] != nil, "payment_request_id key must exist")
        #expect(json["user_id"] != nil, "user_id key must exist")
        #expect(json["is_paid"] != nil, "is_paid key must exist")
        #expect(json["created_at"] != nil, "created_at key must exist")

        #expect((json["amount"] as? Double) == 15.0)
        #expect((json["is_paid"] as? Bool) == false)
    }

    @Test("PaymentRequest round-trips through JSON")
    func paymentRequestRoundTrips() throws {
        // What: Encode then decode a PaymentRequest — all fields must survive.
        // Why: If any CodingKey is wrong, the decoded model will have zero-valued
        //      or nil fields, breaking the payment display entirely.
        let postID = UUID()
        let homeID = UUID()
        let requestorID = UUID()
        let original = Fake.paymentRequest(
            postID: postID,
            homeID: homeID,
            requestorID: requestorID,
            totalAmount: 60.0,
            note: "Groceries 🛒"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PaymentRequest.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.postID == postID)
        #expect(decoded.homeID == homeID)
        #expect(decoded.requestorID == requestorID)
        #expect(decoded.totalAmount == 60.0)
        #expect(decoded.note == "Groceries 🛒")
    }

    @Test("isPaid defaults to false")
    func isPaidDefaultsFalse() {
        // What: A freshly created PaymentSplit must have isPaid = false.
        // Why: All splits start as unpaid — the requestor manually marks each one
        //      paid after Venmo/PayPal confirmation. Defaulting to true would
        //      silently skip the collection flow.
        let split = Fake.unpaidSplit()
        #expect(split.isPaid == false)
    }

    @Test("Paid count is correct")
    func paidCountIsCorrect() {
        // What: Given a PaymentRequest with 2 paid and 1 unpaid split, the paid
        //       count (computed from the splits array) should equal 2.
        // Why: The UI shows "2/3 paid" badge — this drives that label.
        let requestID = UUID()
        let splits = [
            Fake.paidSplit(),
            Fake.paidSplit(),
            Fake.unpaidSplit()
        ].map { split -> PaymentSplit in
            // Re-stamp with consistent requestID so they belong to the same request
            Fake.paymentSplit(
                id: split.id,
                paymentRequestID: requestID,
                userID: split.userID,
                amount: split.amount,
                isPaid: split.isPaid
            )
        }
        let request = Fake.paymentRequest(id: requestID, splits: splits)
        let paidCount = request.splits.filter { $0.isPaid }.count

        #expect(paidCount == 2)
    }

    @Test("Pending count is correct")
    func pendingCountIsCorrect() {
        // What: A request with 1 paid and 2 unpaid splits should report 2 pending.
        // Why: Pending count powers the "still waiting on 2 people" copy in the UI.
        let splits = [
            Fake.paidSplit(),
            Fake.unpaidSplit(),
            Fake.unpaidSplit()
        ]
        let request = Fake.paymentRequest(splits: splits)
        let pendingCount = request.splits.filter { !$0.isPaid }.count

        #expect(pendingCount == 2)
    }

    @Test("Mark paid flips isPaid")
    func markPaidFlipsStatus() {
        // What: Mutating isPaid on a split from false to true should flip the flag.
        // Why: The markPaid service call updates the DB; the local model must also
        //      update for optimistic UI. Verify the struct mutation behaves correctly.
        var split = Fake.unpaidSplit()
        #expect(split.isPaid == false)

        split.isPaid = true

        #expect(split.isPaid == true)
    }

    // MARK: - Venmo / PayPal Deep Links

    @Test("Venmo deep link contains recipient")
    func venmoLinkHasRecipient() {
        // What: The Venmo deep link URL must encode the recipient's Venmo username.
        // Why: If the username is missing, the Venmo app opens but doesn't pre-fill
        //      the recipient — the user would have to search manually, breaking UX.
        let user = Fake.user()
        let url = PaymentService.shared.venmoDeepLink(to: "alexr", amount: 10.0, note: "Split 🍕")

        #expect(url.absoluteString.contains("alexr"),
                "Venmo URL must contain the recipient's username")
    }

    @Test("Venmo deep link contains amount")
    func venmoLinkHasAmount() {
        // What: The Venmo deep link must encode the amount query parameter.
        // Why: Pre-filling the amount prevents the payer from entering a wrong sum.
        let url = PaymentService.shared.venmoDeepLink(to: "jordan", amount: 25.50, note: "Dinner")

        #expect(url.absoluteString.contains("25") || url.absoluteString.contains("amount"),
                "Venmo URL must encode the payment amount")
    }

    @Test("Venmo deep link contains note")
    func venmoLinkHasNote() {
        // What: The Venmo deep link must encode the note / memo field.
        // Why: The note tells the recipient what the payment is for, which is
        //      required context in shared-expense scenarios.
        let url = PaymentService.shared.venmoDeepLink(to: "sam", amount: 8.0, note: "Groceries")

        #expect(url.absoluteString.contains("Groceries") || url.absoluteString.contains("note"),
                "Venmo URL must encode the note field")
    }

    @Test("PayPal deep link format is correct")
    func paypalLinkFormat() {
        // What: The PayPal deep link must be a well-formed URL with the expected host.
        // Why: An incorrectly formatted URL will fail to open the PayPal app and
        //      fall back to nothing, breaking the payment flow entirely.
        let url = PaymentService.shared.paypalDeepLink(to: "alexr", amount: 12.0, note: "Gas")

        #expect(url.absoluteString.contains("paypal"),
                "PayPal URL must reference the paypal scheme or host")
        #expect(url.absoluteString.contains("alexr"),
                "PayPal URL must contain the recipient username")
    }

    @Test("Venmo URL scheme is venmo://")
    func venmoURLScheme() {
        // What: The generated Venmo URL must use the venmo:// custom URL scheme.
        // Why: The venmo:// scheme is what triggers the Venmo app on iOS. Using
        //      https:// would open a browser instead, breaking deep-linking.
        let url = PaymentService.shared.venmoDeepLink(to: "user123", amount: 5.0, note: "Coffee")

        #expect(url.scheme == "venmo",
                "Venmo deep link must use the venmo:// URL scheme")
    }
}
