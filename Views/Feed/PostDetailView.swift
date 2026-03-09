import SwiftUI

struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PostDetailViewModel
    @State private var showEmojiPicker = false
    @FocusState private var composerFocused: Bool

    init(post: Post) {
        _viewModel = State(initialValue: PostDetailViewModel(post: post))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        postContent
                            .padding(.horizontal)
                            .padding(.top)

                        Divider()
                            .padding(.vertical, 12)

                        reactionBar
                            .padding(.horizontal)

                        reactButton
                            .padding(.horizontal)
                            .padding(.top, 12)

                        if viewModel.post.isSystemPost {
                            Divider()
                                .padding(.vertical, 12)
                            reminderSection
                                .padding(.horizontal)
                        }

                        Divider()
                            .padding(.vertical, 16)

                        commentsSection
                            .padding(.horizontal)

                        // Scroll anchor at the bottom of comments
                        Color.clear
                            .frame(height: 1)
                            .id("commentsBottom")
                    }
                }
                .onChange(of: viewModel.comments.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("commentsBottom", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            // Comment composer pinned above keyboard
            .safeAreaInset(edge: .bottom) {
                commentComposer
            }
            // Emoji picker sheet
            .sheet(isPresented: $showEmojiPicker) {
                emojiPickerSheet
                    .presentationDetents([.height(100)])
            }
            .task {
                let userID = appState.currentUser?.id ?? UUID()
                async let _ = viewModel.loadDetails(userID: userID)
                async let _ = viewModel.loadReactions(postID: viewModel.post.id)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
    }

    // MARK: - Post Content

    private var postContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Author header
            HStack {
                if viewModel.post.isSystemPost {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 42, height: 42)
                        .overlay(Text("🏠").font(.system(size: 22)))
                } else {
                    let username = viewModel.post.author?.username ?? "user"
                    Circle()
                        .fill(avatarColor(for: username))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Text(viewModel.post.author?.name.prefix(1) ?? "?")
                                .font(.headline)
                                .foregroundStyle(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.post.author?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    Text(viewModel.post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if viewModel.post.isSystemPost {
                    Text("📢 Reminder")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(Color.orange)
                        .clipShape(Capsule())
                } else {
                    Text("\(viewModel.post.category.emoji) \(viewModel.post.category.label)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor(viewModel.post.category).opacity(0.15))
                        .foregroundStyle(categoryColor(viewModel.post.category))
                        .clipShape(Capsule())
                }
            }

            // Full-width image
            if let imageURL = viewModel.post.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 240)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Caption text
            if !viewModel.post.text.isEmpty {
                Text(viewModel.post.text)
                    .font(.body)
            }
        }
    }

    // MARK: - Reaction Bar

    private var reactionBar: some View {
        let userID = appState.currentUser?.id ?? UUID()
        let summary = viewModel.reactionSummary(userID: userID)
        return VStack(alignment: .leading, spacing: 8) {
            if summary.isEmpty {
                Text("No reactions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(summary, id: \.emoji) { item in
                            Button {
                                Task {
                                    await viewModel.toggleReaction(emoji: item.emoji, userID: userID)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(item.emoji)
                                    Text("\(item.count)")
                                        .font(.caption.bold())
                                        .foregroundStyle(item.hasReacted ? Color.white : Color.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(item.hasReacted ? Color(red: 0.2, green: 0.5, blue: 1.0) : Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - React Button

    private var reactButton: some View {
        Button {
            showEmojiPicker = true
        } label: {
            HStack {
                Spacer()
                Text("React 😄")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.orange.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Emoji Picker Sheet

    private var emojiPickerSheet: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(presetReactions, id: \.self) { emoji in
                    Button {
                        let userID = appState.currentUser?.id ?? UUID()
                        Task {
                            await viewModel.toggleReaction(emoji: emoji, userID: userID)
                        }
                        showEmojiPicker = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Reminder Section (grab history + member rotation)

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            let grabs = viewModel.reminderGrabs.isEmpty
                ? (viewModel.post.reminder?.grabs ?? [])
                : viewModel.reminderGrabs
            let members = viewModel.post.homeMembers ?? []
            let claimerID = viewModel.post.reminder?.currentClaimerID

            // Member rotation — who is most overdue
            if !members.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who's Up")
                        .font(.headline)
                    VStack(spacing: 6) {
                        ForEach(membersSortedByLastGrab(members: members, grabs: grabs)) { member in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(avatarColorForMember(member.username))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Text(member.name.prefix(1))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.subheadline.bold())
                                    if let lastGrab = grabs.filter({ $0.userID == member.id }).map({ $0.grabbedAt }).max() {
                                        Text("Last grabbed \(lastGrab.formatted(.relative(presentation: .named)))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Never grabbed it")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if member.id == claimerID {
                                    Text("Grabbing it ✅")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }
                    }
                }
            }

            // Grab history
            if !grabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grab History")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(grabs) { grab in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(avatarColorForMember(grab.user?.username ?? ""))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Text(grab.user?.name.prefix(1) ?? "?")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                Text(grab.user?.name ?? "Someone")
                                    .font(.subheadline)
                                Spacer()
                                Text(grab.grabbedAt.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("No one has grabbed this yet — be the first!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func membersSortedByLastGrab(members: [User], grabs: [ReminderGrab]) -> [User] {
        members.sorted { a, b in
            let aLast = grabs.filter { $0.userID == a.id }.map { $0.grabbedAt }.max()
            let bLast = grabs.filter { $0.userID == b.id }.map { $0.grabbedAt }.max()
            switch (aLast, bLast) {
            case (nil, nil): return a.name < b.name
            case (nil, _): return true
            case (_, nil): return false
            case (let aDate, let bDate): return aDate! < bDate!
            }
        }
    }

    private func avatarColorForMember(_ username: String) -> Color {
        Color(hue: Double(username.hashValue & 0xFF) / 255, saturation: 0.6, brightness: 0.75)
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Comments")
                .font(.headline)
                .padding(.bottom, 8)

            if viewModel.isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if viewModel.comments.isEmpty {
                Text("No comments yet — be the first! 💬")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentRowView(comment: comment)
                        if comment.id != viewModel.comments.last?.id {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Comment Composer

    private var commentComposer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Add a comment…", text: $viewModel.commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .focused($composerFocused)

                Button {
                    composerFocused = false
                    Task {
                        if let user = appState.currentUser {
                            await viewModel.submitComment(userID: user.id, currentUser: user)
                        }
                    }
                } label: {
                    Text("Send 🚀")
                        .font(.subheadline.bold())
                        .foregroundStyle(viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.orange)
                }
                .disabled(
                    viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isSubmittingComment
                )
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Helpers

    private func avatarColor(for username: String) -> Color {
        Color(
            hue: Double(username.hashValue & 0xFF) / 255,
            saturation: 0.6,
            brightness: 0.8
        )
    }

    private func categoryColor(_ cat: PostCategory) -> Color {
        switch cat {
        case .chore: return Color.blue
        case .purchase: return Color.green
        case .general: return Color.orange
        case .request: return Color.purple
        }
    }
}
