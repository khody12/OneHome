# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

OneHome is an iOS app for roommates to manage shared home responsibilities. It's social-media-style: users post chores done, purchases made, and give each other kudos. The tone is warm, emoji-heavy, tongue-in-cheek, and occasionally roasts slackers.

## Tech Stack

- **iOS 26+**, Swift
- **Supabase** backend (self-hosted locally on Mac)
- Simulator only for now (no Apple Developer account)

## Architecture

### Auth
Minimal login: username/email + password via Supabase Auth.

### Data Model

**User** — username, name, profile picture, date joined, lifetime metrics (chores done, money spent per home)

**Home** — home_id, date_created, owner, list of roommates. One user can own multiple homes. Owner invites others by username; invitees accept before joining.

**Post** — id, home_id, user_id, time_created, category (chore | purchase | general), picture, text, kudos, comments. Posts are saved to the DB immediately as drafts when creation begins.

**StickyNote** — short ephemeral messages (e.g. "hey lock the door"). Lives in the feed, expires after 48 hours, not permanently stored.

**Feed** — ordered collection of Posts and StickyNotes for a given Home.

### Key Features

- **Feed tab** — main home feed showing posts and sticky notes
- **Camera tab** — primary post creation flow (draft-on-open)
- **Metrics view** — each roommate's lifetime contributions to the home
- **Contributions tab** — per-person breakdown of chores and spending
- **Kudos** — only reaction type (no likes)
- **Slacker roast** — if all other roommates have posted in the last 72 hours and you haven't, the app auto-posts/notifies calling you out
- **Contacts integration** — see which contacts are on OneHome, quickly invite them to your Home
- **Payment integration** — Venmo/PayPal deep link or split request for shared purchases (if APIs allow)

## Xcode Project Registration

**Every new `.swift` file MUST be added to `OneHome.xcodeproj/project.pbxproj` or Xcode will not compile it.** Placing a file on disk is not enough — Xcode only builds files explicitly registered in the project manifest.

When you create a new `.swift` file, you must add three entries to `project.pbxproj`:

1. **PBXFileReference** — declares the file exists (in the `Begin PBXFileReference section`)
2. **PBXBuildFile** — adds it to a build phase (in the `Begin PBXBuildFile section`)
3. **PBXGroup children** — places it in the correct folder group so it appears in Xcode's navigator
4. **PBXSourcesBuildPhase files** — adds it to the correct target's compile sources (main app target or test target)

Use unique 24-character hex IDs for each entry. Main app sources go in the first `PBXSourcesBuildPhase` block; test sources go in the second.

If you forget this and see `Cannot find type 'X' in scope` for a type that clearly exists as a file, a missing `.pbxproj` registration is the cause.
