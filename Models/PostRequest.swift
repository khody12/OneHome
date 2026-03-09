import Foundation

// MARK: - PostRequestMetadata
//
// A local-only struct (not Codable) used to carry request-specific metadata
// through the post wizard when creating a `.request` category post.

struct PostRequestMetadata {
    /// The IDs of users this request is assigned to. Empty = open to everyone.
    var requestedUserIDs: [UUID]
    /// Optional extra context beyond the post text.
    var note: String
}
