import SwiftUI
import UIKit

// MARK: - Mode

enum PaymentRequestMode {
    case create(postID: UUID, homeID: UUID, requestorID: UUID, members: [User])
    case view(post: Post)
}

// MARK: - PaymentRequestView

struct PaymentRequestView: View {
    let mode: PaymentRequestMode

    @State private var vm = PaymentViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .create(let postID, let homeID, let requestorID, let members):
                    createContent(postID: postID, homeID: homeID, requestorID: requestorID, members: members)
                case .view(let post):
                    viewContent(post: post)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.orange)
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Create Mode

    @ViewBuilder
    private func createContent(postID: UUID, homeID: UUID, requestorID: UUID, members: [User]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("💸 Request Payment")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Amount field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Amount")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    HStack {
                        Text("$")
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", value: $vm.totalAmount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }

                // Note field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    TextField("What was this purchase? 🛒", text: $vm.note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                }

                // Split evenly / custom toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    Picker("Split type", selection: $vm.splitEvenly) {
                        Text("Split Evenly").tag(true)
                        Text("Custom Amounts").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                }

                // Roommate picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Who owes you?")
                            .font(.headline)
                        Spacer()
                        Button("Select All") {
                            vm.selectAll(members: members, excludingID: requestorID)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 20)

                    let eligibleMembers = members.filter { $0.id != requestorID }
                    ForEach(eligibleMembers) { member in
                        roommateRow(member)
                    }
                }

                // Split summary
                if !vm.selectedMembers.isEmpty && vm.totalAmount > 0 {
                    splitSummarySection(members: members, requestorID: requestorID)
                }

                // Confirm button
                Button {
                    Task {
                        await vm.createRequest(postID: postID, homeID: homeID, requestorID: requestorID)
                        if vm.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                        }
                        Text("Add Payment Request 💸")
                            .font(.body.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        (vm.selectedMembers.isEmpty || vm.totalAmount <= 0 || vm.isLoading)
                            ? Color.orange.opacity(0.4)
                            : Color.orange,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(vm.selectedMembers.isEmpty || vm.totalAmount <= 0 || vm.isLoading)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .navigationTitle("Request Payment")
    }

    @ViewBuilder
    private func roommateRow(_ member: User) -> some View {
        let isSelected = vm.selectedMembers.contains(member.id)
        Button {
            vm.toggleMember(member.id)
        } label: {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.orange.opacity(0.25))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(member.name.prefix(1))
                            .font(.headline)
                            .foregroundStyle(.orange)
                    )

                Text(member.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.orange.opacity(0.06) : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func splitSummarySection(members: [User], requestorID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Split Summary")
                .font(.headline)
                .padding(.horizontal, 20)

            let eligibleMembers = members.filter { $0.id != requestorID && vm.selectedMembers.contains($0.id) }
            ForEach(eligibleMembers) { member in
                HStack {
                    Text(member.name)
                        .font(.subheadline)
                    Spacer()
                    if vm.splitEvenly {
                        Text("$\(vm.evenSplitAmount, specifier: "%.2f")")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    } else {
                        TextField("0.00", value: Binding(
                            get: { vm.customAmounts[member.id] ?? 0 },
                            set: { vm.customAmounts[member.id] = $0 }
                        ), format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .frame(width: 80)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - View Mode

    @ViewBuilder
    private func viewContent(post: Post) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("💸 Payment Request")
                        .font(.title2.bold())
                    if let request = vm.paymentRequest {
                        Text(request.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("$\(request.totalAmount, specifier: "%.2f") total")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        HStack(spacing: 8) {
                            Text("\(request.paidCount) paid")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                            Text("\(request.pendingCount) pending")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if vm.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let request = vm.paymentRequest {
                    ForEach(request.splits) { split in
                        SplitRowView(
                            split: split,
                            requestor: post.author,
                            currentUserID: appState.currentUser?.id,
                            onMarkPaid: {
                                Task { await vm.markPaid(splitID: split.id) }
                            }
                        )
                    }
                } else {
                    Text("No payment request found.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Payment Request")
        .task {
            await vm.loadRequest(for: post.id)
        }
    }
}

// MARK: - SplitRowView

private struct SplitRowView: View {
    let split: PaymentSplit
    let requestor: User?
    let currentUserID: UUID?
    let onMarkPaid: () -> Void

    @State private var showPostPayAlert = false

    var isCurrentUser: Bool { split.userID == currentUserID }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            let initials = split.user?.name.prefix(1) ?? "?"
            Circle()
                .fill(isCurrentUser ? Color.orange.opacity(0.3) : Color(.secondarySystemFill))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(isCurrentUser ? Color.orange : Color.secondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(split.user?.name ?? "Unknown")
                        .font(.subheadline.bold())
                    if isCurrentUser {
                        Text("(you)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("$\(split.amount, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Payment action
            if split.isPaid {
                Text("✅ Paid")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            } else {
                paymentButtons
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            isCurrentUser
                ? Color.orange.opacity(0.05)
                : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .padding(.horizontal, 20)
        .alert("Did you complete the payment?", isPresented: $showPostPayAlert) {
            Button("Yes, mark as paid") { onMarkPaid() }
            Button("Not yet", role: .cancel) { }
        }
    }

    @ViewBuilder
    private var paymentButtons: some View {
        VStack(spacing: 6) {
            if let venmo = requestor?.venmoUsername {
                Button {
                    let url = PaymentService.shared.venmoDeepLink(
                        to: venmo,
                        amount: split.amount,
                        note: "Payment"
                    )
                    UIApplication.shared.open(url)
                } label: {
                    Text("Pay via Venmo 💜")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.2, green: 0.42, blue: 0.8), in: Capsule())
                }
                .buttonStyle(.plain)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    showPostPayAlert = true
                }
            }

            if let paypal = requestor?.paypalUsername {
                Button {
                    let url = PaymentService.shared.paypalDeepLink(
                        to: paypal,
                        amount: split.amount
                    )
                    UIApplication.shared.open(url)
                } label: {
                    Text("Pay via PayPal 🔵")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.0, green: 0.46, blue: 0.75), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if requestor?.venmoUsername == nil && requestor?.paypalUsername == nil {
                Button(action: onMarkPaid) {
                    Text("Mark as Paid ✓")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
