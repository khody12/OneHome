import SwiftUI

struct RequestCardView: View {
    let post: Post
    let home: Home
    var onComplete: () -> Void

    @State private var showDetail = false
    @State private var showCompleteSheet = false
    @State private var localCompletionPostID: UUID? = nil

    private let requestPurple = Color(red: 0.5, green: 0.2, blue: 0.9)

    private var isCompleted: Bool {
        localCompletionPostID != nil || post.completionPostID != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Circle()
                    .fill(requestPurple.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(post.author?.name.prefix(1) ?? "?")
                            .font(.headline)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Text("🙋 Request")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(requestPurple.opacity(0.15))
                    .foregroundStyle(requestPurple)
                    .clipShape(Capsule())
            }

            // Assigned to
            if let ids = post.requestedUserIDs, !ids.isEmpty {
                let assignedMembers = (home.members ?? []).filter { ids.contains($0.id) }
                if !assignedMembers.isEmpty {
                    HStack(spacing: 6) {
                        Text("Assigned to")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(assignedMembers) { member in
                            Circle()
                                .fill(requestPurple.opacity(0.2))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text(member.name.prefix(1))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(requestPurple)
                                )
                        }
                        Text(assignedMembers.map { $0.name }.joined(separator: ", "))
                            .font(.caption.bold())
                    }
                }
            }

            // Post text
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
            }

            // Status + action row
            HStack(spacing: 10) {
                if isCompleted {
                    Text("✅ Completed")
                        .font(.caption.bold())
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Text("⏳ Awaiting response")
                        .font(.caption.bold())
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Button {
                        showCompleteSheet = true
                    } label: {
                        Text("Complete this 💪")
                            .font(.caption.bold())
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(requestPurple, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            PostDetailView(post: post)
        }
        .sheet(isPresented: $showCompleteSheet) {
            CompleteRequestSheet(requestPost: post, home: home) { completionID in
                localCompletionPostID = completionID
                showCompleteSheet = false
                onComplete()
            }
        }
    }
}

// MARK: - Complete Request Sheet

struct CompleteRequestSheet: View {
    let requestPost: Post
    let home: Home
    let onDone: (UUID) -> Void

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var replyText = ""
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Context banner
                VStack(alignment: .leading, spacing: 6) {
                    Text("Replying to request")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(requestPost.text)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Reply text
                TextField("What did you do? 💪", text: $replyText, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Spacer()

                // Post button
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isPosting { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text("Post Completion ✅")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting
                            ? Color.orange.opacity(0.4)
                            : Color.orange,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Complete Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        guard let userID = appState.currentUser?.id else { return }
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPosting = true

        let completionID = UUID()

#if DEBUG
        if home.id == DevPreview.home.id {
            // In dev mode: just create a fake completion post ID and link it
            try? await Task.sleep(nanoseconds: 500_000_000)
            onDone(completionID)
            isPosting = false
            return
        }
#endif

        do {
            // Create a chore post as the completion
            var completionPost = try await PostService.shared.createDraft(
                homeID: home.id, userID: userID, category: .chore
            )
            completionPost.text = trimmed
            try await PostService.shared.updateDraft(completionPost)
            try await PostService.shared.publish(postID: completionPost.id)
            try await PostService.shared.completeRequest(
                requestPostID: requestPost.id,
                completionPostID: completionPost.id
            )
            onDone(completionPost.id)
        } catch {
            // fallback: still mark complete optimistically
            onDone(completionID)
        }
        isPosting = false
    }
}
