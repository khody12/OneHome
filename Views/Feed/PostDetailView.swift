import SwiftUI

struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PostDetailViewModel
    @State private var showKudosList = false
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

                        kudosSection
                            .padding(.horizontal)

                        giveKudosButton
                            .padding(.horizontal)
                            .padding(.top, 12)

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
            .sheet(isPresented: $showKudosList) {
                KudosListView(kudosUsers: viewModel.kudosUsers)
                    .presentationDetents([.medium, .large])
            }
            .task {
                if let userID = appState.currentUser?.id {
                    await viewModel.loadDetails(userID: userID)
                }
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
                let username = viewModel.post.author?.username ?? "user"
                Circle()
                    .fill(avatarColor(for: username))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(viewModel.post.author?.name.prefix(1) ?? "?")
                            .font(.headline)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.post.author?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    Text(viewModel.post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Category badge
                Text("\(viewModel.post.category.emoji) \(viewModel.post.category.label)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(viewModel.post.category).opacity(0.15))
                    .foregroundStyle(categoryColor(viewModel.post.category))
                    .clipShape(Capsule())
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

    // MARK: - Kudos Section

    private var kudosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.post.kudosCount > 0 {
                Button {
                    showKudosList = true
                } label: {
                    HStack(spacing: -8) {
                        // Up to 5 avatar circles
                        ForEach(viewModel.kudosUsers.prefix(5)) { user in
                            Circle()
                                .fill(avatarColor(for: user.username))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(user.name.prefix(1))
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                )
                                .overlay(
                                    Circle().stroke(Color(.systemBackground), lineWidth: 2)
                                )
                        }

                        if viewModel.kudosUsers.count > 5 {
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text("+\(viewModel.kudosUsers.count - 5)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                )
                                .overlay(
                                    Circle().stroke(Color(.systemBackground), lineWidth: 2)
                                )
                        }

                        Text(kudosSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 14)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("No kudos yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var kudosSummaryText: String {
        let count = viewModel.post.kudosCount
        if count == 1 {
            return "\(count) kudos"
        }
        return "\(count) kudos"
    }

    // MARK: - Give Kudos Button

    private var giveKudosButton: some View {
        Button {
            Task {
                if let userID = appState.currentUser?.id {
                    await viewModel.toggleKudos(userID: userID)
                }
            }
        } label: {
            HStack {
                Spacer()
                Text(viewModel.post.hasGivenKudos ? "🙌 You kudos'd this" : "👏 Give Kudos")
                    .font(.headline)
                    .foregroundStyle(viewModel.post.hasGivenKudos ? .white : .white)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(viewModel.post.hasGivenKudos ? Color.orange : Color.orange.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .scaleEffect(viewModel.kudosBounce ? 1.08 : 1.0)
        .animation(
            .spring(response: 0.25, dampingFraction: 0.5),
            value: viewModel.kudosBounce
        )
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
        }
    }
}
