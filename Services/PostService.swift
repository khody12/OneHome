import Supabase
import Foundation

/// Handles post creation (with draft), publishing, reactions, and comments
class PostService {
    static let shared = PostService()
    private init() {}

    // Create a draft post immediately on camera tab open
    func createDraft(homeID: UUID, userID: UUID, category: PostCategory) async throws -> Post {
        let insert = PostInsert(homeID: homeID, userID: userID, category: category, text: "", isDraft: true)
        let posts: [Post] = try await supabase
            .from("posts")
            .insert(insert)
            .select()
            .execute()
            .value
        guard let post = posts.first else { throw AppError.notFound }
        return post
    }

    // Save draft changes
    func updateDraft(_ post: Post) async throws {
        try await supabase
            .from("posts")
            .update(PostUpdate(text: post.text, imageURL: post.imageURL, category: post.category, choreSubcategory: post.choreSubcategory))
            .eq("id", value: post.id)
            .execute()
    }

    // Publish a draft — sets is_draft = false
    func publish(postID: UUID) async throws {
        try await supabase
            .from("posts")
            .update(["is_draft": false])
            .eq("id", value: postID)
            .execute()

        // Update last_post_at in user_metrics
        // (handled via DB trigger ideally, but can also do here)
    }

    // Fetch published posts for a home, newest first
    func fetchFeed(for homeID: UUID) async throws -> [Post] {
        let posts: [Post] = try await supabase
            .from("posts")
            .select("*, author:users(*), comments(*, author:users(*))")
            .eq("home_id", value: homeID)
            .eq("is_draft", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
        return posts
    }

    // MARK: - Comments

    /// Fetches the full comment list for a post, sorted oldest first.
    func fetchComments(for postID: UUID) async throws -> [Comment] {
        let comments: [Comment] = try await supabase
            .from("comments")
            .select("*, author:users(*)")
            .eq("post_id", value: postID)
            .order("created_at", ascending: true)
            .execute()
            .value
        return comments
    }

    func addComment(postID: UUID, userID: UUID, text: String) async throws -> Comment {
        let insert = CommentInsert(postID: postID, userID: userID, text: text)
        let comments: [Comment] = try await supabase
            .from("comments")
            .insert(insert)
            .select("*, author:users(*)")
            .execute()
            .value
        guard let comment = comments.first else { throw AppError.notFound }
        return comment
    }

    // MARK: - Requests

    /// Mark a post as the completion of a request post.
    func completeRequest(requestPostID: UUID, completionPostID: UUID) async throws {
        try await supabase
            .from("posts")
            .update(["completion_post_id": completionPostID.uuidString])
            .eq("id", value: requestPostID)
            .execute()
    }

    /// Fetch a post by ID (used to load the completion post).
    func fetchPost(id: UUID) async throws -> Post {
        let posts: [Post] = try await supabase
            .from("posts")
            .select("*, author:users(*), comments(*, author:users(*))")
            .eq("id", value: id)
            .execute()
            .value
        guard let post = posts.first else { throw AppError.notFound }
        return post
    }
}

private struct PostInsert: Encodable {
    let homeID: UUID
    let userID: UUID
    let category: PostCategory
    let text: String
    let isDraft: Bool
    enum CodingKeys: String, CodingKey {
        case homeID = "home_id"
        case userID = "user_id"
        case category, text
        case isDraft = "is_draft"
    }
}

private struct PostUpdate: Encodable {
    let text: String
    let imageURL: String?
    let category: PostCategory
    let choreSubcategory: ChoreSubcategory?
    enum CodingKeys: String, CodingKey {
        case text, category
        case imageURL = "image_url"
        case choreSubcategory = "chore_subcategory"
    }
}

private struct CommentInsert: Encodable {
    let postID: UUID
    let userID: UUID
    let text: String
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case text
    }
}
