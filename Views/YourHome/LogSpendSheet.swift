import SwiftUI

struct LogSpendSheet: View {
    @Bindable var vm: YourHomeViewModel
    let home: Home
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Amount input
                VStack(spacing: 8) {
                    Text("How much? 💵")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("0.00", value: $vm.logAmount, format: .currency(code: "USD"))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 24)

                // Category picker
                VStack(spacing: 12) {
                    Text("Category")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(SpendCategory.allCases, id: \.rawValue) { category in
                            Button {
                                vm.logCategory = category
                            } label: {
                                VStack(spacing: 4) {
                                    Text(category.emoji)
                                        .font(.title2)
                                    Text(category.label)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    vm.logCategory == category
                                    ? Color.orange.opacity(0.2)
                                    : Color(.secondarySystemBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            vm.logCategory == category ? Color.orange : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Note field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    TextField("e.g. Whole Foods run 🛒", text: $vm.logNote)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                Spacer()

                // Submit button
                Button {
                    Task {
                        if let userID = appState.currentUser?.id {
                            await vm.logSpend(home: home, userID: userID)
                        }
                        dismiss()
                    }
                } label: {
                    Text("Log it 📝")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.logAmount > 0 ? Color.orange : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }
                .disabled(vm.logAmount <= 0)
                .padding(.bottom, 24)
            }
            .navigationTitle("Log a Spend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
