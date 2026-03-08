import Supabase
import UIKit
import Foundation

// MARK: - StorageService
// NOTE: The "post-images" bucket must be created in the Supabase Dashboard first.
// Go to: Storage > New Bucket > Name: "post-images" > Public: true
// Then run Database/storage_setup.sql to apply the RLS policies.

/// Uploads and manages images in Supabase Storage bucket "post-images"
class StorageService {
    static let shared = StorageService()
    private init() {}

    private let bucket = "post-images"

    // Upload a UIImage as JPEG to storage. Returns the public URL string.
    // Path: {homeID}/{userID}/{postID}.jpg
    func uploadPostImage(_ image: UIImage, homeID: UUID, userID: UUID, postID: UUID) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.invalidInput("Could not compress image")
        }
        let path = "\(homeID)/\(userID)/\(postID).jpg"
        try await supabase.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try getPublicURL(for: path)
    }

    // Get the public URL for a stored image path
    func getPublicURL(for path: String) throws -> String {
        let response = try supabase.storage.from(bucket).getPublicURL(path: path)
        return response.absoluteString
    }

    // Delete an image when a post is deleted
    func deletePostImage(homeID: UUID, userID: UUID, postID: UUID) async throws {
        let path = "\(homeID)/\(userID)/\(postID).jpg"
        try await supabase.storage.from(bucket).remove(paths: [path])
    }
}
