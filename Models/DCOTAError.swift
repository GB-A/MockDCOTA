import Foundation

/// Error contract shared by the in-memory mock and the remote API
/// (the REST server returns `{ "code": "...", "message": "..." }`).
enum DCOTAError: Error, Equatable, LocalizedError {
    case validation(String)      // 400 / 422
    case notFound(String)        // 404
    case conflict(String)        // 409
    case server(String)          // 5xx
    case network(String)         // transport

    var errorDescription: String? {
        switch self {
        case .validation(let m), .notFound(let m), .conflict(let m),
             .server(let m), .network(let m):
            return m
        }
    }

    var code: String {
        switch self {
        case .validation: "VALIDATION_ERROR"
        case .notFound: "NOT_FOUND"
        case .conflict: "CONFLICT"
        case .server: "SERVER_ERROR"
        case .network: "NETWORK_ERROR"
        }
    }

    static func from(code: String, message: String) -> DCOTAError {
        switch code {
        case "VALIDATION_ERROR": .validation(message)
        case "NOT_FOUND": .notFound(message)
        case "CONFLICT": .conflict(message)
        default: .server(message)
        }
    }
}

struct APIErrorBody: Codable {
    let code: String
    let message: String
}
