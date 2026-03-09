import SwiftUI

struct PostCardView: View {
    let post: Post
    let currentUserID: UUID
    let onReact: (String) -> Void
    var onClaim: ((UUID) -> Void)? = nil
    @State private var showDetail = false
    @State private var showPaymentSheet = false
    @State private var showEmojiPicker = false

    // Read reactions directly from post so the view always reflects ViewModel state
    private var reactions: [Reaction] { post.reactions ?? [] }

    private var reactionSummary: [(emoji: String, count: Int, hasReacted: Bool)] {
        var grouped: [String: [Reaction]] = [:]
        for r in reactions { grouped[r.emoji, default: []].append(r) }
        return grouped.map { emoji, group in
            (emoji: emoji, count: group.count, hasReacted: group.contains { $0.userID == currentUserID })
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                if post.isSystemPost {
                    // Home system post — house emoji avatar
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(Text("🏠").font(.system(size: 18)))
                } else {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(Text(post.author?.name.prefix(1) ?? "?").font(.headline))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if post.isSystemPost {
                    // System posts get a distinct announcement badge
                    Text("📢 Reminder")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(Color.orange)
                        .clipShape(Capsule())
                } else {
                    HStack(spacing: 6) {
                        Text("\(post.category.emoji) \(post.category.label)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(categoryColor(post.category).opacity(0.15))
                            .foregroundStyle(categoryColor(post.category))
                            .clipShape(Capsule())
                        if let sub = post.choreSubcategory, sub != .other {
                            Text("\(sub.emoji) \(sub.label)")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Image (if any)
            if let imageURL = post.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.secondary.opacity(0.2))
                }
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Text
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
            }

            // System post extras: unclaimed member avatars + claim/claimer section
            if post.isSystemPost {
                systemPostExtras
            }

            // Payment bar (purchase posts)
            if post.category == .purchase, let request = post.paymentRequest {
                Button { showPaymentSheet = true } label: {
                    HStack(spacing: 6) {
                        Text("💸")
                        Text(String(format: "$%.2f split %d way%@", request.totalAmount, request.splits.count, request.splits.count == 1 ? "" : "s"))
                            .font(.caption.bold())
                        Text("—")
                            .foregroundStyle(.secondary)
                        Text("\(request.paidCount) paid, \(request.pendingCount) pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

            // Reaction chips — inline in card, not an overlay (hidden for system posts)
            if !post.isSystemPost && !reactionSummary.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(reactionSummary, id: \.emoji) { item in
                            Button { onReact(item.emoji) } label: {
                                HStack(spacing: 3) {
                                    Text(item.emoji)
                                    Text("\(item.count)")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    item.hasReacted
                                        ? Color(red: 0.2, green: 0.5, blue: 1.0)
                                        : Color(.tertiarySystemBackground)
                                )
                                .foregroundStyle(item.hasReacted ? Color.white : Color.primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Actions row (hidden for system posts)
            if !post.isSystemPost {
                HStack(spacing: 4) {
                    Text("💬")
                    Text("\(post.comments?.count ?? 0) comment\(post.comments?.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Hold to react")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        // Tap anywhere → open detail
        .onTapGesture { showDetail = true }
        // Long press → emoji picker (disabled for system posts)
        .onLongPressGesture { if !post.isSystemPost { showEmojiPicker = true } }
        .sheet(isPresented: $showDetail) {
            PostDetailView(post: post)
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet { emoji in
                onReact(emoji)
                showEmojiPicker = false
            }
            .presentationDetents([.height(100)])
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentRequestView(mode: .view(post: post))
                .presentationDetents([.large])
        }
    }

    // MARK: - System post extras

    private var systemPostExtras: some View {
        VStack(alignment: .leading, spacing: 10) {
            let grabs = post.reminder?.grabs ?? []
            let claimerID = post.reminder?.currentClaimerID
            let unclaimed = unclaimedMembersSorted(
                members: post.homeMembers ?? [],
                grabs: grabs,
                claimerID: claimerID
            )

            // Avatar row of members who haven't grabbed it this cycle
            if !unclaimed.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(unclaimed.count) \(unclaimed.count == 1 ? "person hasn't" : "people haven't") grabbed it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: -6) {
                        ForEach(unclaimed.prefix(6)) { member in
                            Circle()
                                .fill(avatarColor(for: member.username))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(member.name.prefix(1))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .overlay(Circle().stroke(Color(.secondarySystemBackground), lineWidth: 2))
                        }
                        if unclaimed.count > 6 {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text("+\(unclaimed.count - 6)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.secondary)
                                )
                                .overlay(Circle().stroke(Color(.secondarySystemBackground), lineWidth: 2))
                        }
                    }
                }
            }

            // Claimer banner OR claim button
            if let claimer = post.reminder?.currentClaimerUser {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(claimer.name.prefix(1))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.green)
                        )
                    Text("\(claimer.name) is grabbing it ✅")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.green)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            } else if let reminderID = post.reminderID {
                Button {
                    onClaim?(reminderID)
                } label: {
                    HStack {
                        Spacer()
                        Text("I'll grab it 🙋")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func unclaimedMembersSorted(members: [User], grabs: [ReminderGrab], claimerID: UUID?) -> [User] {
        members
            .filter { $0.id != claimerID }
            .sorted { a, b in
                let aLast = grabs.filter { $0.userID == a.id }.map { $0.grabbedAt }.max()
                let bLast = grabs.filter { $0.userID == b.id }.map { $0.grabbedAt }.max()
                switch (aLast, bLast) {
                case (nil, nil): return a.name < b.name
                case (nil, _): return true   // never grabbed = most overdue
                case (_, nil): return false
                case (let aDate, let bDate): return aDate! < bDate!
                }
            }
    }

    private func avatarColor(for username: String) -> Color {
        Color(hue: Double(username.hashValue & 0xFF) / 255, saturation: 0.6, brightness: 0.75)
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

// MARK: - Emoji Picker Sheet

struct EmojiPickerSheet: View {
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(presetReactions, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
