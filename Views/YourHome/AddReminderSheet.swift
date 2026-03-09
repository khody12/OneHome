import SwiftUI

struct AddReminderSheet: View {
    let vm: YourHomeViewModel
    let home: Home
    let userID: UUID

    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var selectedEmoji: String = "📦"
    @State private var intervalDays: Int = 7

    private let emojiPresets = ["🧻", "🍶", "🧴", "🧼", "🍳", "🧽", "🥤", "🫙", "🧹", "🫧", "📦"]
    private let intervalOptions = [7, 14, 30, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Item name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Item name")
                            .font(.headline)
                        TextField("e.g. Toilet Paper", text: $name)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Emoji picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick an emoji")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(emojiPresets, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .padding(10)
                                            .background(
                                                selectedEmoji == emoji
                                                    ? Color.orange.opacity(0.2)
                                                    : Color(.secondarySystemBackground),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedEmoji == emoji ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    // Interval picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remind every \(intervalDays) days")
                            .font(.headline)
                        HStack(spacing: 10) {
                            ForEach(intervalOptions, id: \.self) { days in
                                Button {
                                    intervalDays = days
                                } label: {
                                    Text("\(days)d")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(intervalDays == days ? .white : .orange)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            intervalDays == days ? Color.orange : Color.orange.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Add button
                    Button {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task {
                            await vm.addReminder(
                                name: name.trimmingCharacters(in: .whitespaces),
                                emoji: selectedEmoji,
                                intervalDays: intervalDays,
                                home: home,
                                userID: userID
                            )
                            dismiss()
                        }
                    } label: {
                        Text("Add Reminder")
                            .font(.body.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                name.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.orange.opacity(0.4)
                                    : Color.orange,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .navigationTitle("New Reminder 🔔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
