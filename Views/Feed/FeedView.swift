import SwiftUI

struct FeedView: View {
    let home: Home
    @State private var vm = FeedViewModel()
    @State private var showStickyNoteSheet = false
    @State private var stickyText = ""
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.feedItems.isEmpty {
                    ProgressView("Loading the chaos... 🌀")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Slacker banners at top
                            ForEach(vm.slackers) { metrics in
                                SlackerBannerView(metrics: metrics)
                            }

                            // Feed items
                            ForEach(vm.feedItems) { item in
                                switch item {
                                case .post(let post):
                                    if post.category == .request {
                                        RequestCardView(post: post, home: home) {
                                            // onComplete: reload the feed after completion
                                            Task { await vm.loadFeed(for: home) }
                                        }
                                    } else {
                                        PostCardView(
                                            post: post,
                                            currentUserID: appState.currentUser?.id ?? UUID(),
                                            onReact: { emoji in
                                                Task {
                                                    await vm.addReaction(
                                                        emoji: emoji,
                                                        on: post,
                                                        userID: appState.currentUser?.id ?? UUID()
                                                    )
                                                }
                                            },
                                            onClaim: { reminderID in
                                                guard let me = appState.currentUser else { return }
                                                Task {
                                                    await vm.claimReminder(
                                                        reminderID: reminderID,
                                                        claimer: me,
                                                        home: home
                                                    )
                                                }
                                            }
                                        )
                                    }
                                case .stickyNote(let note):
                                    StickyNoteCardView(note: note)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await vm.loadFeed(for: home)
                    }
                }
            }
            .navigationTitle(home.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showStickyNoteSheet = true
                    } label: {
                        Label("Sticky", systemImage: "note.text.badge.plus")
                    }
                }
            }
            .task {
                await vm.loadFeed(for: home)
            }
        }
        .sheet(isPresented: $showStickyNoteSheet) {
            StickyNoteEntrySheet(text: $stickyText) {
                Task {
                    await vm.addStickyNote(text: stickyText, home: home, userID: appState.currentUser!.id)
                    stickyText = ""
                    showStickyNoteSheet = false
                }
            }
        }
    }
}

struct SlackerBannerView: View {
    let metrics: UserMetrics

    var body: some View {
        HStack {
            Text("😴 \(metrics.user?.name ?? "Someone") hasn't done ANYTHING lately. Embarrassing.")
                .font(.caption.bold())
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(10)
        .background(Color.red.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StickyNoteEntrySheet: View {
    @Binding var text: String
    let onPost: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Leave a note 📌")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Post") {
                            onPost()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}
