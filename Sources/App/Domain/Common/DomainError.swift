import Vapor

enum DomainError: Error {
    case badRequest(String)
    case notFound(String?)
    case conflict(String)
    case forbidden(String)
    case unauthorized(String)
    case internalError(String)
}

extension DomainError {
    func asAbort() -> Abort {
        switch self {
        case let .badRequest(reason):
            return Abort(.badRequest, reason: reason)
        case let .notFound(reason):
            return Abort(.notFound, reason: reason ?? "Not found.")
        case let .conflict(reason):
            return Abort(.conflict, reason: reason)
        case let .forbidden(reason):
            return Abort(.forbidden, reason: reason)
        case let .unauthorized(reason):
            return Abort(.unauthorized, reason: reason)
        case let .internalError(reason):
            return Abort(.internalServerError, reason: reason)
        }
    }
}
