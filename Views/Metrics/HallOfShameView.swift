import SwiftUI

struct HallOfShameView: View {
    let slackers: [UserMetrics]
    let allMetrics: [UserMetrics]

    // 10 snarky, funny roast messages — seeded by userID for consistency
    private static let roastMessages: [String] = [
        "hasn't lifted a finger since joining 🦥",
        "we're starting to think they live here rent-free 🛋️",
        "their chore list is collecting more dust than the shelves 🧹💤",
        "reportedly 'very busy' — we're not buying it 🙄",
        "the dishes have been waiting for them longer than a Netflix series 📺",
        "contributes mainly by existing in the group chat 💬",
        "their idea of chores is occasionally blinking 👀",
        "even the mop has worked harder this week 🫧",
        "mysteriously unavailable every time cleaning day rolls around 📅",
        "living proof that some people peak at moving in 🏠"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hall of Shame 🫵")
                    .font(.headline)
                Spacer()
                Text("\(slackers.count) slacker\(slackers.count == 1 ? "" : "s")")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.red, in: Capsule())
            }

            ForEach(slackers) { slacker in
                shameCard(for: slacker)
            }
        }
        .padding()
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.red.opacity(0.25), lineWidth: 1.5)
        )
    }

    // MARK: - Shame Card

    private func shameCard(for m: UserMetrics) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(m.user?.name.prefix(1) ?? "?"))
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(m.user?.name ?? "Unknown")
                    .font(.subheadline.bold())
                Text(roastMessage(for: m))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let days = daysSinceLastPost(m) {
                    Text("Last seen: \(days) day\(days == 1 ? "" : "s") ago")
                        .font(.caption2.bold())
                        .foregroundStyle(.red.opacity(0.7))
                } else {
                    Text("Last seen: never 👻")
                        .font(.caption2.bold())
                        .foregroundStyle(.red.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(10)
        .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    /// Deterministically picks a roast based on the user ID so it doesn't
    /// shuffle on every redraw, yet still feels "random" per person.
    private func roastMessage(for m: UserMetrics) -> String {
        let index = abs(m.userID.hashValue) % HallOfShameView.roastMessages.count
        return HallOfShameView.roastMessages[index]
    }

    private func daysSinceLastPost(_ m: UserMetrics) -> Int? {
        guard let last = m.lastPostAt else { return nil }
        return max(0, Int(Date().timeIntervalSince(last) / 86400))
    }
}
