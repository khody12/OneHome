// TestAudit.swift
// OneHome — Test Coverage Audit
//
// Conducted: 2026-03-08
// Auditor: Continuous Testing Agent
//
// ============================================================
// SUMMARY
// ============================================================
//
// Total existing test files scanned: 16
// Total test cases found (approx): 107
// Critical gaps identified: 17
// Placeholder assertions found: 1 (StorageTests — nilImageThrows uses #expect(true))
// Partially covered areas: 6
//
// ============================================================
// FILE-BY-FILE FINDINGS
// ============================================================
//
// ── Tests/ModelTests.swift (10 tests) ─────────────────────
//   COVERED:
//     ✓ StickyNote active / expired basic cases
//     ✓ UserMetrics.isSlacking — basic 3-way comparison
//     ✓ UserMetrics.isSlacking — never-posted-is-slacking
//     ✓ PostCategory allCases have emojis
//     ✓ PostCategory Codable round-trip
//     ✓ FeedItem sort order (sticky note vs post)
//
//   GAPS:
//     ✗ StickyNote.isExpired at EXACT boundary (+1s / -1s)
//       (ScenarioTests hits -0.001s but not the +1s / -1s exact boundary)
//     ✗ isSlacking when home has only ONE user (no others → should be false)
//     ✗ isSlacking when own post is EXACTLY at 72h boundary
//     ✗ FeedItem.post case exposes correct id and createdAt via computed props
//       (ScenarioTests covers this lightly but ModelTests misses it)
//     ✗ UserMetrics with choresDone=0 for everyone — rank math still valid
//
// ── Tests/AuthTests.swift (12 tests) ──────────────────────
//   COVERED:
//     ✓ Empty email/password/username/name validation
//     ✓ Successful signIn/signUp → AppState changes
//     ✓ signOut → clears user/home/isAuthenticated
//     ✓ Auth error → errorMessage set
//     ✓ New user has no home after sign-up
//     ✓ isLoading resets after signIn/signUp fail
//
//   GAPS:
//     ✗ signUp with duplicate email (invalidInput error) already partially
//       covered in "signUpErrorSetsMessage" — complete enough.
//     ✗ No test for AppState initial state (isAuthenticated=false,
//       currentUser=nil, currentHome=nil) — these are trivially verifiable
//       but untested.
//
// ── Tests/CameraTests.swift (9 tests) ─────────────────────
//   COVERED:
//     ✓ Draft created on capture, text-only draft (no imageURL)
//     ✓ Publishing sets isPosted=true, clears draft
//     ✓ All 3 categories selectable / AllCases.count == 3
//     ✓ Reset clears all VM state
//     ✓ Category emojis exact values
//     ✓ Draft ownership (homeID + userID)
//     ✓ Category subtitles non-empty
//     ✓ Submit propagates category and text
//
//   GAPS:
//     ✗ selectedCategory is NOT reset in reset() — currently documented
//       with an inline comment but there's no test that would FAIL if
//       reset() starts resetting selectedCategory. A brittle contract.
//     ✗ PostCategory.subtitle extension is tested for non-empty but the
//       exact subtitle strings are never pinned.
//
// ── Tests/DatabaseConsistencyTests.swift (14 tests) ───────
//   COVERED:
//     ✓ User / Post / Home / StickyNote / UserMetrics CodingKey smoke tests
//     ✓ Round-trip JSON for all main models
//     ✓ is_draft true/false in JSON
//     ✓ UserMetrics nil lastPostAt encodes
//     ✓ PostCategory raw values / JSON value / schema coverage
//
//   GAPS:
//     ✗ Comment CodingKeys (post_id, user_id, created_at) — no explicit test
//       in this file (ScenarioTests covers round-trip but not key names)
//     ✗ PendingInvite CodingKeys — model now exists, no consistency test
//     ✗ Post.hasGivenKudos is NOT in CodingKeys — verify it's absent from JSON
//       (it's local-state only; encoding it would be a bug)
//
// ── Tests/MetricsTests.swift (14 tests) ───────────────────
//   COVERED:
//     ✓ Ranked list descending, rank correct in 4-person home
//     ✓ Rank 1 / rank N / single-person rank
//     ✓ totalChoresDone / totalSpent sums, empty-list zeros
//     ✓ Slacker list empty when all active, multiple slackers shown
//     ✓ Never-posted is slacker, slackers.count == 1
//     ✓ currentUserMetrics populated after load, nil without userID
//     ✓ isLoading reset, load with error leaves empty
//     ✓ Days since last post arithmetic
//     ✓ homeScenario slacker/rank/totalChores assertions
//
//   GAPS:
//     ✗ isSlacking when only one user (single-person home → always false)
//     ✗ Rank when two users have identical choresDone (tie-breaking undefined)
//
// ── Tests/Fixtures/Fake.swift ──────────────────────────────
//   STATUS: Good. Covers all existing models.
//   GAPS:
//     ✗ No Fake.pendingInvite() factory — needed for InviteService tests
//     ✗ No Fake.acceptedInvite() / Fake.declinedInvite() — needed for status tests
//     ✗ No Fake.comment(withAuthor:) convenience overload — minor
//
// ── Tests/Mocks/Protocols.swift ───────────────────────────
//   STATUS: All existing services have protocols.
//   GAPS:
//     ✗ No StorageServiceProtocol — needed to mock image upload in tests
//     ✗ No InviteServiceProtocol — InviteViewModel uses InviteService.shared directly
//     ✗ No ContactsServiceProtocol — needed to mock permission denial
//
// ── Tests/Mocks/MockPostService.swift ─────────────────────
//   STATUS: Complete — tracks all PostServiceProtocol methods.
//   GAPS:
//     ✗ No fetchComments / fetchKudosUsers tracking — PostDetailViewModel uses these
//       (PostService.shared.fetchComments / fetchKudosUsers don't exist in protocol yet)
//
// ── Tests/Mocks/Mock{Home,Auth,Metrics,StickyNote}Service.swift ─
//   STATUS: All complete and correct.
//   GAPS: None for existing features.
//
// ── Tests/ViewModelTests/FeedViewModelTests.swift (11 tests) ─
//   COVERED:
//     ✓ loadFeed merge + sort, slackers detected, empty feed, errors
//     ✓ toggleKudos optimistic increment/decrement, calls service, sticks on error
//     ✓ addStickyNote prepends, error sets message
//
//   GAPS:
//     ✗ Drafts excluded from feed (FeedViewModel receives only published posts
//       from service, so filtering is implicit — but no explicit assertion)
//     ✗ loadFeed when notes service throws (covered for metrics/post but not notes)
//
// ── Tests/ViewModelTests/HomeViewModelTests.swift (10 tests) ─
//   COVERED:
//     ✓ loadHomes populates, empty is OK, error, passes userID
//     ✓ createHome appends+clears, empty guard, no-user guard, error, ownerID
//     ✓ joinHome appends+clears, empty code guard, no-user guard, error, code passthrough
//
//   GAPS:
//     ✗ loadHomes isLoading resets after error — tested for createHome but not loadHomes
//
// ── Tests/ViewModelTests/PostViewModelTests.swift (11 tests) ─
//   COVERED:
//     ✓ startDraft success/idempotent/error/leaves nil
//     ✓ publish success/no-draft/post error/metrics error
//     ✓ reset full / reset on clean
//     ✓ saveDraft syncs fields, no-draft noop
//
//   GAPS:
//     ✗ submitPost is NOT tested — it's a new combined method with image upload logic
//     ✗ isUploadingImage flag behavior during submitPost
//     ✗ uploadProgress = 1.0 after successful upload
//
// ── Tests/IntegrationTests/ScenarioTests.swift (22 tests) ─
//   COVERED:
//     ✓ Full feed sort, slacker detection, never-posted, all-slacking, active not flagged
//     ✓ Kudos increment/decrement/floor
//     ✓ Draft filtering, draft properties
//     ✓ Sticky note expiry filter, boundary, 48h TTL
//     ✓ JSON round-trips (User, Post, Home, Comment)
//     ✓ PostCategory metadata / raw values / Codable
//     ✓ Metrics independence / MetricsViewModel.ranked sort
//     ✓ FeedItem.id / FeedItem.createdAt delegation
//     ✓ AppError descriptions
//     ✓ Fake factory shape validation
//
//   GAPS:
//     ✗ AppState initial state not tested (isAuthenticated=false, currentUser=nil)
//     ✗ Home: owner NOT automatically in members (members is separate from ownerID)
//
// ── Tests/StorageTests.swift (6 tests) ────────────────────
//   COVERED:
//     ✓ Path contains homeID/userID/postID / ends in .jpg
//     ✓ JPEG compression at 0.8 ≤ compression at 1.0
//     ✓ isUploadingImage starts false
//     ✓ uploadedImageURL starts nil
//     ✓ uploadProgress starts 0.0
//
//   PLACEHOLDER:
//     ✗ "nilImageThrows" test uses `#expect(true)` — THIS IS A PLACEHOLDER.
//       The test documents behavior but makes no real assertion on one branch.
//
//   GAPS:
//     ✗ No MockStorageService — PostViewModel.submitPost cannot be tested without one
//     ✗ StorageService has no protocol — injection impossible currently
//
// ============================================================
// COMPLETE LIST OF UNCOVERED BEHAVIORS (priority order)
// ============================================================
//
//  P0 — Placeholder that always passes
//    1. StorageTests.nilImageThrows uses #expect(true) on the nil branch
//
//  P1 — Feature behaviors with zero tests
//    2. InviteViewModel — no test file exists at all
//    3. PostDetailViewModel — no test file exists at all
//    4. PendingInvite Codable / CodingKeys — no test
//    5. AppState initial state (isAuthenticated=false, currentUser=nil, currentHome=nil)
//    6. InviteService (via mock) — no test exercises the invite flow
//
//  P2 — Edge cases missing from existing suites
//    7. isSlacking for a single-user home (no others → should always return false)
//    8. isSlacking at exact 72h boundary (posted exactly 72h ago → NOT slacking)
//    9. Post.hasGivenKudos absent from JSON (it's local state only)
//   10. StickyNote.isExpired exactly +1s in future → false
//   11. StickyNote.isExpired exactly -1s in past → true
//   12. Comment CodingKeys exact key names (post_id, user_id, created_at)
//   13. Home owner is NOT automatically a member (members array is separate)
//   14. kudosCount defaults to 0 (default parameter in Fake, but no test pins it)
//   15. hasGivenKudos defaults to false at struct level (not from Fake)
//   16. UserMetrics all-zero choresDone → no ranking order guarantee
//   17. FeedItem two items same createdAt coexist without crash
//
//  P3 — New features being added (tests written in NewFeatureCoverageTests.swift)
//   18. Image upload — StorageService path, compression, progress, URLs
//   19. InviteViewModel.inviteByUsername with empty trimmed username blocked
//   20. InviteViewModel.contactsPermissionDenied set on permission denial
//   21. PostDetailViewModel initializes comments from post / empty
//   22. PostDetailViewModel empty/whitespace comment not submitted
//   23. PostDetailViewModel comment text cleared after submit
//   24. PostDetailViewModel kudos toggle flips hasGivenKudos + count
//   25. PostDetailViewModel comments sorted oldest-first
//   26. Avatar color deterministic per username

// This file contains no executable code — it is audit documentation only.
