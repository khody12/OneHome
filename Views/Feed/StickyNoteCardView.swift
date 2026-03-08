import SwiftUI

struct StickyNoteCardView: View {
    let note: StickyNote

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("📌")
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(.subheadline)

                HStack {
                    Text("— \(note.author?.name ?? "someone")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("expires \(note.expiresAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
    }
}
