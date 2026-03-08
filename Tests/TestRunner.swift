// OneHome Test Runner
//
// ============================================================
// RUNNING TESTS IN XCODE
// ============================================================
//
// Run all tests:
//   Product > Test  (Cmd+U)
//
// Run a specific test suite:
//   Open the Test Navigator (Cmd+6), click the play button next to any suite.
//
// Run a specific test method:
//   Click the diamond icon in the gutter next to the @Test function.
//
// ============================================================
// RUNNING TESTS FROM THE COMMAND LINE
// ============================================================
//
// Run all tests on the simulator:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//
// Run only scenario tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/ScenarioTests
//
// Run only sticky note model tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/StickyNoteTests
//
// Run only feed ViewModel tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/FeedViewModelTests
//
// Run only post ViewModel tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/PostViewModelTests
//
// Run only home ViewModel tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/HomeViewModelTests
//
// Run only UserMetrics model tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/UserMetricsTests
//
// Run only edge case gap-fill tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/EdgeCaseTests
//
// Run only image upload tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/ImageUploadTests
//
// Run only invite system tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/InviteSystemTests
//
// Run only post detail / comments tests:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/PostDetailTests
//
// Run all new-feature coverage tests (image, invite, reactions) at once:
//   xcodebuild test \
//     -scheme OneHome \
//     -destination 'platform=iOS Simulator,name=iPhone 16' \
//     -only-testing:OneHomeTests/NewFeatureCoverageTests
//
// ============================================================
// XCODE PROJECT SETUP (one-time)
// ============================================================
//
// 1. In Xcode, select File > New > Target > Unit Testing Bundle
// 2. Name the target "OneHomeTests"
// 3. Set "Target to be Tested" to "OneHome"
// 4. Add all files under Tests/ to the OneHomeTests target:
//      - Tests/ModelTests.swift
//      - Tests/Fixtures/Fake.swift
//      - Tests/Mocks/Protocols.swift
//      - Tests/Mocks/MockPostService.swift
//      - Tests/Mocks/MockHomeService.swift
//      - Tests/Mocks/MockStickyNoteService.swift
//      - Tests/Mocks/MockMetricsService.swift
//      - Tests/Mocks/MockAuthService.swift
//      - Tests/ViewModelTests/FeedViewModelTests.swift
//      - Tests/ViewModelTests/HomeViewModelTests.swift
//      - Tests/ViewModelTests/PostViewModelTests.swift
//      - Tests/IntegrationTests/ScenarioTests.swift
//      - Tests/TestAudit.swift
//      - Tests/EdgeCaseTests.swift
//      - Tests/NewFeatureCoverageTests.swift
//      - Tests/Mocks/MockStorageService.swift
//      - Tests/Mocks/MockInviteService.swift
//
// 5. In each file, the `@testable import OneHome` gives access to
//    internal types. The module name must match the Xcode target name.
//
// ============================================================
// TEST FILE MAP
// ============================================================
//
//   Tests/ModelTests.swift
//     Pure model unit tests — StickyNote expiry, slacker detection,
//     PostCategory codable, FeedItem sorting. No mocks needed.
//
//   Tests/Fixtures/Fake.swift
//     Central fake data factory. Every model has a static make() function.
//     Fake.homeScenario() returns a complete 3-user home for scenario tests.
//
//   Tests/Mocks/Protocols.swift
//     Service protocols extracted from concrete classes, enabling injection.
//
//   Tests/Mocks/MockPostService.swift
//     Tracks fetchFeed, toggleKudos, addComment, createDraft, publish, updateDraft.
//
//   Tests/Mocks/MockHomeService.swift
//     Tracks fetchHomes, createHome, joinHomeByCode, fetchMembers.
//
//   Tests/Mocks/MockStickyNoteService.swift
//     Tracks post(), fetchActive(), delete().
//
//   Tests/Mocks/MockMetricsService.swift
//     Tracks fetchMetrics(), recordPost().
//
//   Tests/Mocks/MockAuthService.swift
//     Tracks signUp, signIn, signOut, currentUser.
//
//   Tests/ViewModelTests/FeedViewModelTests.swift
//     Feed loading, merge sort, slacker population, kudos toggle (optimistic
//     update + revert), addStickyNote prepend, error paths.
//
//   Tests/ViewModelTests/HomeViewModelTests.swift
//     loadHomes, createHome (success + empty name guard + no user guard + error),
//     joinHome (success + empty code guard + not found error).
//
//   Tests/ViewModelTests/PostViewModelTests.swift
//     startDraft (success + idempotency + error), publish (success + no-draft guard +
//     service errors), reset, saveDraft field sync.
//
//   Tests/IntegrationTests/ScenarioTests.swift
//     End-to-end scenarios using only local Swift logic and Fake data.
//     Covers feed merge/sort, all slacker edge cases, kudos arithmetic,
//     draft filtering, sticky note expiry, JSON serialization, category
//     metadata, and factory validation.
//
//   Tests/TestAudit.swift
//     Documentation-only file. Records all coverage gaps found during the
//     2026-03-08 audit. No executable code.
//
//   Tests/EdgeCaseTests.swift
//     Gap-fill tests for AppError, AppState initial state, FeedItem delegation,
//     Home edge cases (inviteCode JSON, owner vs members), Post encoding edge cases
//     (is_draft key, hasGivenKudos absence, kudosCount default, category emojis),
//     UserMetrics boundary cases (single-user, 72h boundary), Comment CodingKeys,
//     and StickyNote exact expiry boundaries (+1s / -1s).
//     Suites: AppErrorEdgeCaseTests, AppStateInitialStateTests, FeedItemEdgeCaseTests,
//             HomeEdgeCaseTests, PostEdgeCaseTests, UserMetricsBoundaryCaseTests,
//             CommentEdgeCaseTests, StickyNoteExactBoundaryTests.
//
//   Tests/NewFeatureCoverageTests.swift
//     Forward tests for the three new features being added in parallel.
//     Uses only types that already exist — compiles today.
//     Suites: ImageUploadTests, InviteSystemTests, PostDetailTests.
//
//   Tests/Mocks/MockStorageService.swift
//     StorageServiceProtocol + MockStorageService with uploadCallCount,
//     deleteCallCount, urlToReturn, errorToThrow, and captured parameter tracking.
//
//   Tests/Mocks/MockInviteService.swift
//     InviteServiceProtocol + MockInviteService tracking inviteByUsername,
//     fetchPendingInvites, accept, and decline call counts and arguments.
//
// ============================================================
// FRAMEWORK NOTES
// ============================================================
//
//   - Uses Swift Testing (import Testing), NOT XCTest
//   - @Suite groups related tests; @Test marks individual test functions
//   - #expect() is the assertion macro (replaces XCTAssert*)
//   - Issue.record() is the failure macro (replaces XCTFail)
//   - async tests use `await` directly inside @Test — no XCTestExpectation needed
//   - All tests are purely local — zero network calls, zero Supabase dependency
