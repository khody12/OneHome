import Contacts
import Foundation

// IMPORTANT: Add NSContactsUsageDescription to Info.plist with a message like:
// "OneHome uses your contacts to help you find friends who are already on the app."
// Without this key, the app will crash at runtime when requesting contacts access.

/// Wraps CNContactStore to find which device contacts are registered OneHome users
class ContactsService {
    static let shared = ContactsService()
    private let store = CNContactStore()
    private init() {}

    // Request contacts permission. Returns true if granted.
    func requestPermission() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await store.requestAccess(for: .contacts)
            } catch {
                return false
            }
        default:
            return false
        }
    }

    // Fetch all contact emails from the device
    func fetchContactEmails() async throws -> [String] {
        let keys = [CNContactEmailAddressesKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var emails: [String] = []

        try store.enumerateContacts(with: request) { contact, _ in
            for emailAddress in contact.emailAddresses {
                let email = emailAddress.value as String
                if !email.isEmpty {
                    emails.append(email.lowercased())
                }
            }
        }

        return emails
    }

    // Given a list of emails, return which ones have OneHome accounts.
    // Queries the users table: .in("email", values: emails)
    func findOneHomeUsers(from emails: [String]) async throws -> [User] {
        guard !emails.isEmpty else { return [] }
        let users: [User] = try await supabase
            .from("users")
            .select()
            .in("email", values: emails)
            .execute()
            .value
        return users
    }
}
