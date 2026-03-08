# OneHome — Status

> Last updated: 2026-03-08

---

## Current State: Image upload, invite/contacts, reactions/comments, and 220 tests complete

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

## File Map

```
OneHome/
├── AppError.swift
├── AppState.swift
├── OneHomeApp.swift
├── CLAUDE.md
├── status.md
├── Database/
│   ├── schema.sql
│   ├── storage_setup.sql
│   └── invites_schema.sql
├── Models/
│   ├── Comment.swift
│   ├── FeedItem.swift
│   ├── Home.swift
│   ├── Post.swift
│   ├── StickyNote.swift
│   ├── User.swift
│   └── UserMetrics.swift
├── Services/
│   ├── AuthService.swift
│   ├── ContactsService.swift
│   ├── HomeService.swift
│   ├── InviteService.swift        ← includes PendingInvite model
│   ├── MetricsService.swift
│   ├── PostService.swift
│   ├── StickyNoteService.swift
│   ├── StorageService.swift
│   └── SupabaseConfig.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── FeedViewModel.swift
│   ├── HomeViewModel.swift
│   ├── InviteViewModel.swift
│   ├── MetricsViewModel.swift
│   ├── PostDetailViewModel.swift
│   └── PostViewModel.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Feed/
│   │   ├── CommentRowView.swift
│   │   ├── FeedView.swift
│   │   ├── KudosListView.swift
│   │   ├── PostCardView.swift
│   │   ├── PostDetailView.swift
│   │   └── StickyNoteCardView.swift
│   ├── Home/
│   │   └── HomeSelectionView.swift
│   ├── Invite/
│   │   ├── InviteView.swift
│   │   └── PendingInvitesView.swift
│   ├── Metrics/
│   │   ├── HallOfShameView.swift
│   │   ├── MetricsView.swift
│   │   └── UserMetricsRowView.swift
│   ├── Post/
│   │   ├── CameraTabView.swift
│   │   ├── CameraView.swift
│   │   ├── CategorizeView.swift
│   │   ├── CreatePostView.swift   ← superseded, kept for reference
│   │   └── ReviewPostView.swift
│   └── MainTabView.swift
└── Tests/
    ├── AuthTests.swift
    ├── CameraTests.swift
    ├── DatabaseConsistencyTests.swift
    ├── EdgeCaseTests.swift
    ├── InviteTests.swift
    ├── MetricsTests.swift
    ├── ModelTests.swift
    ├── NewFeatureCoverageTests.swift
    ├── ReactionsTests.swift
    ├── StorageTests.swift
    ├── TestAudit.swift
    ├── TestRunner.swift
    ├── Fixtures/
    │   └── Fake.swift
    ├── IntegrationTests/
    │   └── ScenarioTests.swift
    ├── Mocks/
    │   ├── MockAuthService.swift
    │   ├── MockHomeService.swift
    │   ├── MockInviteService.swift
    │   ├── MockMetricsService.swift
    │   ├── MockPostService.swift
    │   ├── MockStickyNoteService.swift
    │   ├── MockStorageService.swift
    │   └── Protocols.swift
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

---

## Known TODOs / Next up

- [ ] Xcode project setup + SPM (`supabase-swift`)
- [ ] Supabase local instance (`supabase start`, run SQL files in order)
- [ ] Venmo/PayPal deep link for purchase posts
- [ ] Push notifications for slacker roasts
- [ ] Profile view + avatar upload
- [ ] Share sheet for invite code (iOS share sheet via `ShareLink`)
- [ ] Real-time feed updates via Supabase Realtime subscriptions
