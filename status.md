# OneHome — Status

> Last updated: 2026-03-09

---

## Current State: Emoji reactions, request posts, dev mode hardening, and bug fixes complete

---

## Build Log

### v0.1 — Project scaffold
- `CLAUDE.md` written with full product spec, tech stack, and data model

---

### v0.2 — Core data layer + full app skeleton

**Models** (all `Codable`, `Identifiable`, snake_case `CodingKeys` for Supabase)
- `User`, `Home`, `Post`, `StickyNote`, `Comment`, `UserMetrics`, `FeedItem`

**Services** (async/await, Supabase Swift SDK)
- `SupabaseConfig`, `AuthService`, `HomeService`, `PostService`, `StickyNoteService`, `MetricsService`

**ViewModels** (`@Observable`)
- `AppState`, `AuthViewModel`, `FeedViewModel`, `HomeViewModel`, `PostViewModel`, `MetricsViewModel`

**Views**
- `LoginView`, `RegisterView`, `MainTabView`, `HomeSelectionView`, `FeedView`, `PostCardView`, `StickyNoteCardView`

**Database**: `Database/schema.sql` — 8 tables, RLS, kudos trigger, 3 RPC functions

---

### v0.3 — Camera tab

- `CameraTabView` — 3-step wizard root
- `CameraView` — AVFoundation: tap-to-focus, front/back flip, shutter flash, permission denied state (`NSCameraUsageDescription` required)
- `CategorizeView` — category cards + caption
- `ReviewPostView` — preview, publish or draft, confirmation message
- Draft written to DB on shutter press (draft-first architecture)
- Modified: `PostViewModel` (capturedImage, submitPost), `MainTabView` (routes to CameraTabView)
- **Tests**: `CameraTests.swift` — 9 tests

---

### v0.4 — Rich metrics + Hall of Shame

- `MetricsView` rewrite — stats header, your-stats card, Swift Charts bar chart, expandable leaderboard, Hall of Shame
- `UserMetricsRowView` — expandable/collapsible with slacking badge
- `HallOfShameView` — 10 roast messages seeded by userID
- Modified: `MetricsViewModel` (currentUserMetrics, slackers, totalChoresDone, totalSpent, currentUserRank)
- **Tests**: `MetricsTests.swift` — 20 tests

---

### v0.5 — Testing harness

- `Tests/Fixtures/Fake.swift` — factory for every model + `Fake.homeScenario()` (3-user scenario)
- Mock services for all 5 services (call tracking, error injection)
- `FeedViewModelTests` (11), `HomeViewModelTests` (11), `PostViewModelTests` (11)
- `AuthTests.swift` (12), `DatabaseConsistencyTests.swift` (14), `ScenarioTests.swift` (27)
- **Total at this point: 99 tests**

---

### v0.6 — Image upload to Supabase Storage

- `StorageService` — upload `UIImage` as JPEG (0.8 quality) to `post-images` bucket at path `{homeID}/{userID}/{postID}.jpg`, get public URL, delete
- `PostViewModel` — upload pipeline before publish, `isUploadingImage`, `uploadProgress`, error bail-out
- `ReviewPostView` — linear progress bar + disabled state during upload
- `Database/storage_setup.sql` — bucket creation + 3 RLS policies
- **Tests**: `StorageTests.swift` — 6 tests
- **Info.plist reminder**: `NSCameraUsageDescription` required

---

### v0.7 — Invite / contacts flow

- `ContactsService` — CNContactStore permission, fetch contact emails, find OneHome users (`NSContactsUsageDescription` required)
- `InviteService` + `PendingInvite` model — invite by username, fetch/accept/decline pending invites
- `InviteViewModel` — contacts permission state, success toast, accept navigates into home
- `PendingInvitesView` — incoming invite sheet with Accept / Decline per row
- `InviteView` — username invite + contacts list section with Settings fallback
- `Database/invites_schema.sql` — `pending_invites` table, check constraint on status, 3 RLS policies
- Modified: `HomeService` (joinHome made internal), `AppState` (pendingInviteCount), `HomeSelectionView` (invite badge + sheets), `Fake.swift` (pendingInvite factories)
- **Tests**: `InviteTests.swift` — 10 tests

---

### v0.8 — Reactions + full comment section

- `PostDetailView` — full-screen sheet: kudos bar (avatar row), animated kudos button, scrollable comments, pinned composer with keyboard avoidance
- `PostDetailViewModel` — optimistic kudos + comment with server reconciliation, reverts on error
- `KudosListView` — who gave kudos, `.presentationDetents([.medium, .large])`
- `CommentRowView` — avatar color seeded by username hash, relative timestamps, long-press to copy
- `PostService` extended: `fetchKudosUsers(for:)`, `fetchComments(for:)`
- Modified: `PostCardView` (inline comments removed → sheet trigger), `PostService` (2 new methods)
- **Tests**: `ReactionsTests.swift` — 11 tests

---

### v0.9 — Continuous testing coverage

- `Tests/TestAudit.swift` — documented 26 coverage gaps found across 16 files
- `Tests/EdgeCaseTests.swift` — 34 tests filling gaps: AppError, AppState init state, FeedItem delegation, Home JSON, Post CodingKeys, UserMetrics boundaries, Comment CodingKeys, StickyNote exact expiry
- `Tests/NewFeatureCoverageTests.swift` — 39 tests for image upload (8), invite system (12), post detail/reactions (19)
- `Tests/Mocks/MockStorageService.swift` — `StorageServiceProtocol` + mock
- `Tests/Mocks/MockInviteService.swift` — `InviteServiceProtocol` + mock
- Modified: `Fake.swift` (acceptedInvite, declinedInvite), `TestRunner.swift` (new suite commands)
- **Total: 220 tests across 15 test files. All local — no network required.**

---

### v0.10 — Payment requests (Venmo/PayPal deep links)

- `Models/PaymentRequest.swift` — `PaymentRequest` + `PaymentSplit` structs, `Codable`, `paidCount`/`pendingCount` computed
- `Services/PaymentService.swift` — `createRequest`, `markPaid`, `fetchRequest`, `venmoDeepLink(to:amount:note:)`, `paypalDeepLink(to:amount:)`
- `ViewModels/PaymentViewModel.swift` — split-evenly/custom toggle, `selectAll`, `toggleMember`, `evenSplitAmount`, create and view mode loading
- `Views/Post/PaymentRequestView.swift` — two modes: create (amount + note + member picker + split summary) and view (SplitRowView per split with Venmo 💜 / PayPal 🔵 buttons, `UIApplication.didBecomeActiveNotification` → "Did you complete the payment?" alert, ✅ Paid badge)
- Modified: `Models/User.swift` (added `venmoUsername`, `paypalUsername`), `Models/Post.swift` (added `paymentRequest: PaymentRequest?`), `Views/Feed/PostCardView.swift` (payment bar taps open `PaymentRequestView`)
- `Database/payments_schema.sql` — `payment_requests` + `payment_splits` tables, RLS, FK cascade
- **Tests**: `Tests/PaymentTests.swift`, `Tests/Mocks/MockPaymentService.swift`

---

### v0.11 — Your Home tab (subscriptions, spending, roommates)

- `Models/Subscription.swift` — `Subscription` + `SubscriptionMember` + `PopularService` (21 services), `costPerMember` computed
- `Models/SpendLog.swift` — `SpendLog` + `SpendCategory` (food/household/utilities/entertainment/other) with emoji/label
- `Services/SubscriptionService.swift` — create, fetch, delete subscriptions + members
- `Services/SpendLogService.swift` — `logSpend`, `fetchLogs`, `deleteLog`, `totalByCategory`, `totalByUser` helpers
- `ViewModels/YourHomeViewModel.swift` — loads all three (subs/logs/members), `grandTotal`, `totalByCategory`, dev preview short-circuit
- `Views/YourHome/YourHomeView.swift` — scrollable: invite code banner, avatar row, Roommates section (horizontal cards), Spending Overview (donut chart + category breakdown), Recent Purchases (top 5), Subscriptions (swipe-to-delete)
- `Views/YourHome/AddSubscriptionView.swift` — 2-step: service grid picker (search) → configure (cost, billing day, member toggle)
- `Views/YourHome/LogSpendSheet.swift` — big number input + category grid + note field
- `Views/YourHome/SpendHistoryView.swift` — grouped by month, category filter chips, swipe-to-delete own entries
- `Views/YourHome/SubscriptionRowView.swift` — expandable: member avatars + billing day detail
- `Views/YourHome/YourHomeView.swift` also defines: `SectionHeader`, `AvatarCircle`, `RoommateCard`, `SpendLogRow`, `MemberDetailSheet`
- Modified: `MainTabView.swift` (Homes tab → `YourHomeView`), `DevPreview.swift` (subscriptions + spendLogs fake data)
- `Database/home_features_schema.sql` — `subscriptions` + `subscription_members` + `spend_logs` tables, RLS
- **Tests**: `Tests/HomeFeatureTests.swift`, `Tests/Mocks/MockSubscriptionService.swift`, `Tests/Mocks/MockSpendLogService.swift`

---

### v0.12 — Emoji Reactions (replaces Kudos)

- `Models/Reaction.swift` — `Reaction` struct (Codable, Identifiable) + `presetReactions: [String]` global (20 emojis: 🐐 👍 ❤️ 💯 🔥 😂 😮 😢 👏 🙌 💪 🫡 🤩 💀 🫶 ⭐ 🎉 👀 🤝 💅)
- `Services/ReactionService.swift` — `addReaction`, `removeReaction`, `fetchReactions` against `post_reactions` table
- `Database/reactions_schema.sql` — `post_reactions` table with UNIQUE(post_id, user_id, emoji), RLS policies
- Modified: `Models/Post.swift` (removed `kudosCount`/`hasGivenKudos`, added `reactions: [Reaction]?`), `Services/PostService.swift` (removed `toggleKudos`/`fetchKudosUsers`/`KudosInsert`)
- Modified: `Views/Feed/PostCardView.swift` — long-press → emoji picker (horizontal scroll, `.ultraThinMaterial`); blue reaction pill top-right (top 3 emojis + count)
- Modified: `Views/Feed/PostDetailView.swift` — reaction bar with grouped chips (tap to toggle), "React" button
- Modified: `ViewModels/PostDetailViewModel.swift` — `reactions`, `reactionSummary(userID:)`, `loadReactions`, `toggleReaction` (optimistic, revert on fail)
- Modified: `ViewModels/FeedViewModel.swift` — `addReaction` (optimistic, `#if DEBUG` guard)
- Modified: `DevPreview.swift` — `chorePostID`, `reactions` (🐐/👍/❤️ on chore post)
- **Tests**: `ReactionsTests.swift` (16 tests), `MockReactionService.swift`, `ReactionServiceProtocol` in `Protocols.swift`; updated `FeedViewModelTests`, `ScenarioTests`, `EdgeCaseTests`, `NewFeatureCoverageTests`, `DatabaseConsistencyTests`

---

### v0.13 — Request Posts + Threading

- New `.request` category in `PostCategory` (🙋 Request, purple accent `Color(red: 0.5, green: 0.2, blue: 0.9)`)
- `Models/Post.swift` — added `requestedUserIDs: [UUID]?`, `completionPostID: UUID?`, `completionPost: Post?`
- `Database/requests_schema.sql` — `ALTER TABLE posts ADD COLUMN` for both new fields
- `Views/Feed/RequestCardView.swift` — dedicated card: header, "Assigned to" initials row, ⏳/✅ status pill, "Complete this 💪" purple button
- Modified: `Views/Post/CategorizeView.swift` — `.request` subtitle; "Who is this for?" multi-select when request selected; `onNext` extended to 4 args `(PostCategory, String, Bool, [UUID])`
- Modified: `Views/Post/CameraTabView.swift` — `CameraStep.categorize` carries `members: [User]`; `CameraStep.review` carries `requestedUserIDs: [UUID]`
- Modified: `Views/Post/ReviewPostView.swift` — "Assigned to" preview, sets `requestedUserIDs` on draft before submit
- Modified: `Views/Feed/FeedView.swift` — branches `.request` posts to `RequestCardView`
- Modified: `ViewModels/PostDetailViewModel.swift` — `completionPost`, `markComplete(with:)`, `loadDetails` fetches completion post
- Modified: `Services/PostService.swift` — `completeRequest(requestPostID:completionPostID:)`, `fetchPost(id:)`
- Modified: `DevPreview.swift` — `requestPost` with trash-request text, appended to `posts`/`feedItems`
- **Tests**: `RequestTests.swift` (8 tests), `Fake.requestPost(...)`, `Fake.completedRequest(...)`

---

### v0.15 — Household Item Reminders

- `Models/HouseholdReminder.swift` — `HouseholdReminder` struct with snake_case `CodingKeys`; computed helpers `nextDueAt`, `isDue`, `daysOverdue`, `statusLabel`
- `Services/HouseholdReminderService.swift` — singleton; `fetchReminders`, `createReminder`, `clearReminder`, `deleteReminder`; private `HouseholdReminderInsert` / `HouseholdReminderClear` Encodable structs
- `Database/reminders_schema.sql` — `household_reminders` table with FK cascade on `homes`, RLS: read/insert/update/delete restricted to home members
- `ViewModels/YourHomeViewModel.swift` — added `var reminders: [HouseholdReminder] = []`; `load(home:)` now fetches reminders in parallel; `addReminder`, `clearReminder`, `deleteReminder` actions each with `#if DEBUG` dev guard
- `Views/YourHome/AddReminderSheet.swift` — new sheet: item name text field, horizontal emoji preset scroll (11 presets), 4-interval segmented control (7/14/30/60d), orange full-width "Add Reminder" button
- `Views/YourHome/YourHomeView.swift` — added `remindersSection` between Roommates and Spending Overview; `ReminderRowView` card (emoji + name + status label colored red/green + last-buyer caption + interval); `ClearReminderSheet` confirmation; swipe-to-delete; tap-to-clear; `showAddReminder` and `reminderToClear` state
- `DevPreview.swift` — added `static let reminders: [HouseholdReminder]` with Toilet Paper (overdue) and Dish Soap (never cleared)
- `ViewModels/FeedViewModel.swift` — `loadFeed(for:)` now fetches reminders; private `systemPostsForDueReminders(_:)` injects synthetic `Post(author: nil)` for each due reminder; dev mode also injects from `DevPreview.reminders`
- `Views/Feed/PostCardView.swift` — system post support: `post.author == nil` renders house-circle avatar and "🏠 OneHome" author name
- `Views/Post/CameraTabView.swift` — `CameraStep.review` gains `reminderID: UUID?`; `CameraTabView` adds `@State private var dueReminders` loaded via `.task`; threads `dueReminders` into `CategorizeView`
- `Views/Post/CategorizeView.swift` — `onNext` gains 6th arg `UUID?`; `dueReminders: [HouseholdReminder]` prop; "Clear a reminder?" multi-select section shown for `.purchase` posts when there are due reminders; `selectedReminderID` state
- `Views/Post/ReviewPostView.swift` — `reminderID: UUID? = nil` prop; `submitPost` calls `HouseholdReminderService.shared.clearReminder` after successful publish when `reminderID != nil`
- `Tests/ReminderTests.swift` — 16 tests across 3 suites: `isDue`/`nextDueAt`/`daysOverdue`/`statusLabel` model tests; `YourHomeViewModel` dev-mode add/clear/delete tests; `FeedViewModel` system-post injection tests
- `Tests/Mocks/MockHouseholdReminderService.swift` — mock implementing `HouseholdReminderServiceProtocol` with call tracking and error injection
- `Tests/Mocks/Protocols.swift` — added `HouseholdReminderServiceProtocol`
- `Tests/Fixtures/Fake.swift` — added `reminder()`, `dueReminderNeverCleared()`, `overdueReminder()`, `upcomingReminder()` factories

---

### v0.14 — Bug Fix Sprint + Dev Mode Hardening

This version documents fixes applied after v0.12–v0.13 were shipped. No new features — all fixes.

#### Build Errors Fixed

**`CameraTabView` closure mismatch**
- `CategorizeView.onNext` grew to 4 args `(PostCategory, String, Bool, [UUID])` but `CameraTabView` only handled 2. Fixed by threading `wantsPayment: Bool` and `requestedUserIDs: [UUID]` through `CameraStep.review`.

**`PaymentRequestView` extraneous argument label**
- `roommateRow(_ member: User)` (no external label) was called as `roommateRow(member: member)`. Fixed call site to drop the label.

**`Post` recursive struct error ("Value type 'Post' has infinite size")**
- Root cause: `var completionPost: Post?` made `Post` (a struct) reference itself — illegal in Swift. Removing it caused cascades in `RequestCardView` and `PaymentRequestMode` (both embed `Post`).
- Fix: removed `completionPost: Post?` from `Post` entirely. `PostDetailViewModel` (a class, no size constraint) holds `var completionPost: Post?` instead. Only `completionPostID: UUID?` remains on the struct.

**`PostDetailViewModel` still referenced `post.completionPost`**
- After removing the field, `markComplete(with:)` still did `post.completionPost = completionPost`. Removed that line.

#### Dev Mode Fixes (Supabase not running in simulator)

All of these followed the same root cause: operations called real Supabase without a `#if DEBUG` guard. Pattern: every ViewModel write operation needs:
```swift
#if DEBUG
if home.id == DevPreview.home.id { /* in-memory update */ ; return }
#endif
```

**"No draft found. Please restart" on post creation**
- `PostViewModel.startDraft` called `PostService.shared.createDraft` without a dev guard. Added `#if DEBUG` block that creates an in-memory `Post` draft using `DevPreview.home.id` and `DevPreview.user`.

**Sticky notes not appearing in feed**
- `FeedViewModel.addStickyNote` called `StickyNoteService` without dev guard. Added `#if DEBUG` block that constructs a local `StickyNote` and inserts it into `feedItems`.

**Spend logs not saving**
- `YourHomeViewModel.logSpend` called `SpendLogService` without dev guard. Added `#if DEBUG` block that creates a fake `SpendLog` and appends it to `spendLogs`.

#### UI Bugs Fixed

**"5d ago" text wrapping in leaderboard row (`UserMetricsRowView`)**
- Stats HStack got compressed when the "Slacking 😴" badge was also present, pushing the relative date onto a second line.
- Fix: added `.fixedSize()` to each `Label` inside the stats HStack + `.lineLimit(1)` on the row. This prevents compression without fixing the total width.

**Reactions not sticking to posts after ViewModel update**
- Root cause: `PostCardView` had `@State private var reactions: [Reaction]` initialized from `post.reactions` in a custom `init`. In SwiftUI, `@State` only initializes once (on first render) — subsequent parent re-renders (ViewModel updating `feedItems`) do NOT push new values into an existing `@State`. So the card showed stale reactions.
- Fix: removed `@State` and custom `init` entirely. Made `reactions` a pure computed property: `private var reactions: [Reaction] { post.reactions ?? [] }`. Now always reflects current ViewModel state.

**Reaction pills placed in wrong position (overlay top-right)**
- Originally reactions were in a `.overlay(alignment: .topTrailing)` ZStack with `ignoresSafeArea` — this fought the card layout and clipped unpredictably.
- Fix: moved reactions inline into the card body as horizontal-scrolling chip pills, same as `PostDetailView`. Cleaner layout, correct sizing.

**Tap anywhere on post card not opening detail**
- `.onTapGesture` was scoped incorrectly. Applied `.onTapGesture { showDetail = true }` to the whole card's outer `VStack`, plus `.contentShape(RoundedRectangle(cornerRadius: 14))` to ensure the hit-test covers the full rounded rect including padding.

**"Complete this 💪" button doing nothing**
- The button set `showCompleteSheet = true` but the sheet wasn't wired up. Added `CompleteRequestSheet` as a `.sheet(isPresented: $showCompleteSheet)` — it shows the original request as context, lets the person describe what they did, creates a real chore post on submit, then calls `PostService.completeRequest` to link it. Dev mode simulates with a 0.5s delay.
- Added `@State private var localCompletionPostID: UUID?` so the card flips to ✅ immediately on completion without waiting for a feed reload.

**Comments not loading after reactions feature**
- The reactions agent rewrote `.task` in `PostDetailView` to only call `loadReactions`, dropping the `loadDetails` call. This meant comments were never fetched from the server.
- Fix: restored parallel execution of both:
  ```swift
  .task {
      async let _ = viewModel.loadDetails(userID: userID)
      async let _ = viewModel.loadReactions(postID: viewModel.post.id)
  }
  ```

**Comments lost after submitting in dev mode**
- `submitComment` dev early return (inside `#if DEBUG`) exited before setting `post.comments = comments`. The optimistic comment was added locally but the post's own `comments` array wasn't updated, so the next time the detail sheet opened it re-initialized with stale data.
- Fix: added `post.comments = comments` before the early `return` in dev mode.

**Reactions disappear when opening post detail**
- Root cause: `PostDetailViewModel.loadReactions` in dev mode always did `reactions = DevPreview.reactions.filter { $0.postID == postID }`, unconditionally overwriting the array. Any reactions toggled on the feed (and optimistically stored in `FeedViewModel.feedItems`) lived on the `Post` value passed to `PostDetailViewModel.init` — but `loadReactions` clobbered them with the static DevPreview set.
- Fix: only seed from DevPreview if reactions are currently empty (i.e., first open):
  ```swift
  if reactions.isEmpty {
      reactions = DevPreview.reactions.filter { $0.postID == postID }
  }
  return
  ```
  This preserves any session-added reactions while still providing fake data on first open.

**`FeedViewModel.addReaction` logic error**
- The optimistic update and the `#if DEBUG` guard were interleaved incorrectly. Simplified: apply optimistic update unconditionally via nested `applyReactionToggle()` helper, then `#if DEBUG` check is only `if post.homeID == DevPreview.home.id { return }`, then call `ReactionService`.

---

### v0.16 — Chore Subcategories + Category Leaderboards

- **`Models/Post.swift`** — added `ChoreSubcategory` enum (8 cases: cooking/dishes/floors/laundry/trash/groceries/bathrooms/other, each with `label` + `emoji`); added `var choreSubcategory: ChoreSubcategory?` to `Post` with CodingKey `"chore_subcategory"`
- **`Models/CategoryLeaderboardEntry.swift`** (new) — `CategoryLeaderboardEntry` struct: `id: UUID` (userID), `user: User`, `count: Int`, `totalAmount: Double`
- **`Database/chore_subcategory_schema.sql`** (new) — `ALTER TABLE posts ADD COLUMN IF NOT EXISTS chore_subcategory text;`
- **`Services/PostService.swift`** — `PostUpdate` extended with `choreSubcategory: ChoreSubcategory?`; `updateDraft` now persists the subcategory
- **`Services/MetricsService.swift`** — added `fetchChoreLeaderboard(homeID:subcategory:since:)`, `fetchOverallChoreLeaderboard(homeID:since:)`, `fetchSpendLeaderboard(homeID:since:)` (all client-side aggregated from posts table)
- **`Views/Post/CategorizeView.swift`** — `onNext` closure extended to 6 args (added `ChoreSubcategory?`, `UUID?`); horizontal chip picker shown when `.chore` is selected; selection defaults to `.other` on "Next →"
- **`Views/Post/CameraTabView.swift`** — `CameraStep.review` extended with `choreSubcategory: ChoreSubcategory?` + `reminderID: UUID?`; threaded through `.categorize` → `.review`
- **`Views/Post/ReviewPostView.swift`** — added `choreSubcategory: ChoreSubcategory?` + `reminderID: UUID?` params; shows subcategory badge next to category badge; stamps `draft.choreSubcategory` before submit
- **`Views/Feed/PostCardView.swift`** — chore posts with non-`.other` subcategory show a second blue capsule badge
- **`ViewModels/MetricsViewModel.swift`** — added `LeaderboardType` + `TimeRange` enums; new state: `selectedLeaderboard`, `selectedTimeRange`, `selectedChoreSubcategory`, `choreLeaderboards`, `overallChoreLeaderboard`, `spendLeaderboard`; `load` fetches all leaderboards in parallel; `#if DEBUG` dev path computes leaderboards from `DevPreview.posts` + `DevPreview.spendLogs`; added `activeLeaderboardEntries` computed property
- **`Views/Metrics/MetricsView.swift`** — split into "Stats" / "Leaderboard" internal tab picker; Stats tab keeps existing header/chart/rankings/HallOfShame; Leaderboard tab adds type picker, time-range toggle, subcategory chips (Chores mode), and ranked category rows
- **`Views/Metrics/LeaderboardView.swift`** (new) — standalone leaderboard view (same logic as MetricsView's Leaderboard tab) usable independently if wired into MainTabView separately
- **`DevPreview.swift`** — `posts` extended with 6 extra chore posts (one each for dishes, floors, cooking, trash, bathrooms, laundry, groceries) with `choreSubcategory` set; original dish post also gets `.dishes` subcategory
- **`Tests/Fixtures/Fake.swift`** — `Fake.post(...)` factory extended with `choreSubcategory: ChoreSubcategory? = nil`
- **`Tests/Mocks/Protocols.swift`** — `MetricsServiceProtocol` extended with 3 new leaderboard methods
- **`Tests/Mocks/MockMetricsService.swift`** — implements 3 new protocol methods; adds `choreLeaderboardToReturn`, `overallChoreLeaderboardToReturn`, `spendLeaderboardToReturn`; `reset()` clears them
- **`Tests/LeaderboardTests.swift`** (new) — 30 tests: `TimeRange.since`, `LeaderboardType` cases/rawValues, `ChoreSubcategory` labels/emojis/rawValues, `CategoryLeaderboardEntry`, VM state defaults, leaderboard switching, dev-mode computation from DevPreview, post model round-trip

---

## File Map

```
OneHome/
├── AppError.swift
├── AppState.swift
├── DevPreview.swift
├── OneHomeApp.swift
├── CLAUDE.md
├── status.md
├── Database/
│   ├── schema.sql
│   ├── storage_setup.sql
│   ├── invites_schema.sql
│   ├── payments_schema.sql
│   ├── home_features_schema.sql
│   ├── chore_subcategory_schema.sql ← ALTER TABLE posts ADD COLUMN IF NOT EXISTS chore_subcategory text
│   ├── reactions_schema.sql       ← post_reactions table, UNIQUE(post_id, user_id, emoji)
│   ├── reminders_schema.sql       ← household_reminders table, RLS for home members
│   └── requests_schema.sql        ← ALTER TABLE posts: requestedUserIDs, completionPostID
├── Models/
│   ├── Comment.swift
│   ├── FeedItem.swift
│   ├── Home.swift
│   ├── HouseholdReminder.swift    ← HouseholdReminder + nextDueAt/isDue/daysOverdue/statusLabel
│   ├── PaymentRequest.swift       ← PaymentRequest + PaymentSplit
│   ├── CategoryLeaderboardEntry.swift ← new: CategoryLeaderboardEntry struct
│   ├── Post.swift                 ← added ChoreSubcategory enum, choreSubcategory field, reactions:[Reaction]?, requestedUserIDs:[UUID]?, completionPostID:UUID?
│   ├── Reaction.swift             ← Reaction struct + presetReactions[20]
│   ├── SpendLog.swift             ← SpendLog + SpendCategory
│   ├── StickyNote.swift
│   ├── Subscription.swift         ← Subscription + SubscriptionMember + PopularService
│   ├── User.swift
│   └── UserMetrics.swift
├── Services/
│   ├── AuthService.swift
│   ├── ContactsService.swift
│   ├── HomeService.swift
│   ├── HouseholdReminderService.swift ← fetchReminders, createReminder, clearReminder, deleteReminder
│   ├── InviteService.swift        ← includes PendingInvite model
│   ├── MetricsService.swift       ← added fetchChoreLeaderboard, fetchOverallChoreLeaderboard, fetchSpendLeaderboard
│   ├── PaymentService.swift       ← Venmo/PayPal deep links + CRUD
│   ├── PostService.swift          ← added completeRequest, fetchPost; removed toggleKudos
│   ├── ReactionService.swift      ← addReaction, removeReaction, fetchReactions
│   ├── SpendLogService.swift
│   ├── StickyNoteService.swift
│   ├── StorageService.swift
│   ├── SubscriptionService.swift
│   └── SupabaseConfig.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── FeedViewModel.swift
│   ├── HomeViewModel.swift
│   ├── InviteViewModel.swift
│   ├── MetricsViewModel.swift     ← added LeaderboardType, TimeRange enums; leaderboard state + activeLeaderboardEntries
│   ├── PaymentViewModel.swift
│   ├── PostDetailViewModel.swift
│   ├── PostViewModel.swift
│   └── YourHomeViewModel.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift        ← "🛠️ Dev Login" button in DEBUG
│   │   └── RegisterView.swift
│   ├── Feed/
│   │   ├── CommentRowView.swift
│   │   ├── FeedView.swift
│   │   ├── PostCardView.swift     ← reactions as computed property (not @State); inline chips; long-press picker
│   │   ├── PostDetailView.swift   ← reaction bar + React button; loads both details+reactions in parallel
│   │   ├── RequestCardView.swift  ← request card: ⏳/✅ pill; CompleteRequestSheet
│   │   └── StickyNoteCardView.swift
│   ├── Home/
│   │   └── HomeSelectionView.swift
│   ├── Invite/
│   │   ├── InviteView.swift
│   │   └── PendingInvitesView.swift
│   ├── Metrics/
│   │   │   ├── HallOfShameView.swift
│   │   ├── LeaderboardView.swift  ← new: standalone category leaderboard UI
│   │   ├── MetricsView.swift      ← added Stats/Leaderboard internal tab; leaderboard tab with type picker, time range, subcategory chips
│   │   └── UserMetricsRowView.swift
│   ├── Post/
│   │   ├── CameraTabView.swift
│   │   ├── CameraView.swift
│   │   ├── CategorizeView.swift
│   │   ├── CreatePostView.swift   ← superseded, kept for reference
│   │   ├── PaymentRequestView.swift
│   │   └── ReviewPostView.swift
│   ├── YourHome/
│   │   ├── AddReminderSheet.swift ← emoji preset scroll, interval picker, full-width Add button
│   │   ├── AddSubscriptionView.swift
│   │   ├── LogSpendSheet.swift
│   │   ├── SpendHistoryView.swift
│   │   ├── SubscriptionRowView.swift
│   │   └── YourHomeView.swift     ← also: SectionHeader, AvatarCircle, RoommateCard, SpendLogRow, MemberDetailSheet, ReminderRowView, ClearReminderSheet
│   └── MainTabView.swift          ← 4 tabs: Feed | Post | Leaderboard | Home (YourHomeView)
└── Tests/
    ├── AuthTests.swift
    ├── CameraTests.swift
    ├── DatabaseConsistencyTests.swift
    ├── EdgeCaseTests.swift
    ├── HomeFeatureTests.swift
    ├── InviteTests.swift
    ├── MetricsTests.swift
    ├── ModelTests.swift
    ├── NewFeatureCoverageTests.swift
    ├── PaymentTests.swift
    ├── ReactionsTests.swift
    ├── LeaderboardTests.swift     ← 30 tests: TimeRange, LeaderboardType, ChoreSubcategory, CategoryLeaderboardEntry, VM state, dev-mode
    ├── ReminderTests.swift        ← model computed props, VM dev-mode actions, feed injection
    ├── StorageTests.swift
    ├── TestAudit.swift
    ├── TestRunner.swift
    ├── Fixtures/
    │   └── Fake.swift             ← added reminder(), dueReminderNeverCleared(), overdueReminder(), upcomingReminder(); post() extended with choreSubcategory param
    ├── IntegrationTests/
    │   └── ScenarioTests.swift
    ├── Mocks/
    │   ├── MockAuthService.swift
    │   ├── MockHomeService.swift
    │   ├── MockHouseholdReminderService.swift ← call tracking + error injection
    │   ├── MockInviteService.swift
    │   ├── MockMetricsService.swift
    │   ├── MockPaymentService.swift
    │   ├── MockPostService.swift
    │   ├── MockSpendLogService.swift
    │   ├── MockStickyNoteService.swift
    │   ├── MockStorageService.swift
    │   ├── MockSubscriptionService.swift
    │   └── Protocols.swift        ← added HouseholdReminderServiceProtocol
    └── ViewModelTests/
        ├── FeedViewModelTests.swift
        ├── HomeViewModelTests.swift
        └── PostViewModelTests.swift
```

---

## Info.plist requirements
- `NSCameraUsageDescription` — camera tab
- `NSPhotoLibraryUsageDescription` — photo picker
- `NSContactsUsageDescription` — contacts integration

## SQL files to run in order
1. `Database/schema.sql`
2. `Database/storage_setup.sql`
3. `Database/invites_schema.sql`
4. `Database/payments_schema.sql`
5. `Database/home_features_schema.sql`
6. `Database/reactions_schema.sql`
7. `Database/requests_schema.sql`
8. `Database/reminders_schema.sql`
9. `Database/chore_subcategory_schema.sql`

---

## Known TODOs / Next up

- [ ] Supabase local instance (`supabase start`, run SQL files in order)
- [ ] Add `venmo_username` / `paypal_username` columns to `users` table in schema.sql
- [ ] Push notifications for slacker roasts
- [ ] Profile view + avatar upload
- [ ] Share sheet for invite code (iOS share sheet via `ShareLink`)
- [ ] Real-time feed updates via Supabase Realtime subscriptions
