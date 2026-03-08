import Foundation

@Observable
class PaymentViewModel {
    var totalAmount: Double = 0
    var note: String = ""
    var selectedMembers: Set<UUID> = []
    var customAmounts: [UUID: Double] = [:]
    var splitEvenly: Bool = true
    var paymentRequest: PaymentRequest?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed

    /// Split amount per person when splitting evenly (rounded to 2 decimal places).
    var evenSplitAmount: Double {
        guard !selectedMembers.isEmpty else { return 0 }
        return (totalAmount / Double(selectedMembers.count) * 100).rounded() / 100
    }

    // MARK: - Member Selection

    func selectAll(members: [User], excludingID: UUID) {
        selectedMembers = Set(members.compactMap { $0.id == excludingID ? nil : $0.id })
    }

    func toggleMember(_ id: UUID) {
        if selectedMembers.contains(id) {
            selectedMembers.remove(id)
        } else {
            selectedMembers.insert(id)
        }
    }

    // MARK: - Async Actions

    func createRequest(postID: UUID, homeID: UUID, requestorID: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let splits: [(userID: UUID, amount: Double)]
            if splitEvenly {
                splits = selectedMembers.map { (userID: $0, amount: evenSplitAmount) }
            } else {
                splits = selectedMembers.compactMap { id in
                    guard let amt = customAmounts[id] else { return nil }
                    return (userID: id, amount: amt)
                }
            }
            paymentRequest = try await PaymentService.shared.createRequest(
                postID: postID,
                homeID: homeID,
                requestorID: requestorID,
                totalAmount: totalAmount,
                note: note,
                splits: splits
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markPaid(splitID: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            try await PaymentService.shared.markPaid(splitID: splitID)
            // Update local state
            if let idx = paymentRequest?.splits.firstIndex(where: { $0.id == splitID }) {
                paymentRequest?.splits[idx].isPaid = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadRequest(for postID: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            paymentRequest = try await PaymentService.shared.fetchRequest(for: postID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
