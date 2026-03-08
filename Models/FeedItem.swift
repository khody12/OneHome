import Foundation

// Union type for feed — can be a Post or StickyNote
enum FeedItem: Identifiable {
    case post(Post)
    case stickyNote(StickyNote)

    var id: UUID {
        switch self {
        case .post(let p): return p.id
        case .stickyNote(let s): return s.id
        }
    }

    var createdAt: Date {
        switch self {
        case .post(let p): return p.createdAt
        case .stickyNote(let s): return s.createdAt
        }
    }
}
