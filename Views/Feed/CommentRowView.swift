import SwiftUI

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar circle with initial letter, colored by username hash
            avatarCircle

            VStack(alignment: .leading, spacing: 3) {
                // Author name + timestamp
                HStack(spacing: 6) {
                    Text(comment.author?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    Text(relativeTimestamp(comment.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Comment body
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                UIPasteboard.general.string = comment.text
            } label: {
                Label("Copy text", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Helpers

    private var avatarCircle: some View {
        let username = comment.author?.username ?? "?"
        let initial = comment.author?.name.prefix(1) ?? "?"
        return Circle()
            .fill(avatarColor(for: username))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(initial))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            )
    }

    private func avatarColor(for username: String) -> Color {
        Color(
            hue: Double(username.hashValue & 0xFF) / 255,
            saturation: 0.6,
            brightness: 0.8
        )
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60:
            return "just now"
        case 60..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        case 3600..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        default:
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
