import Foundation

protocol UsageProvider: Sendable {
    var id: UsageProviderID { get }
    func fetchUsage() async throws -> UsageSnapshot
}

enum UsageProviderError: LocalizedError {
    case unavailable(String)
    case invalidData(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .invalidData(let message), .processFailed(let message):
            message
        }
    }
}

