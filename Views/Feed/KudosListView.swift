import SwiftUI

struct KudosListView: View {
    let kudosUsers: [User]

    var body: some View {
        NavigationStack {
            Group {
                if kudosUsers.isEmpty {
                    emptyState
                } else {
                    List(kudosUsers) { user in
                        userRow(user)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Kudos 🙌")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("👏")
                .font(.system(size: 60))
            Text("Be the first to give kudos! 👏")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func userRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            // Avatar circle
            Circle()
                .fill(avatarColor(for: user.username))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user.name.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline.bold())
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func avatarColor(for username: String) -> Color {
        Color(
            hue: Double(username.hashValue & 0xFF) / 255,
            saturation: 0.6,
            brightness: 0.8
        )
    }
}
