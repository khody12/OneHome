import Foundation

enum AppError: Error, LocalizedError {
    case notFound
    case unauthorized
    case invalidInput(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Not found 🤷"
        case .unauthorized: return "You're not allowed in here 🚫"
        case .invalidInput(let msg): return msg
        case .networkError(let msg): return "Network issue: \(msg)"
        }
    }
}
