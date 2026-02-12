import Vapor

extension Request {
    func requireUUID(_ key: String) throws -> UUID {
        guard let rawValue = parameters.get(key), let id = UUID(uuidString: rawValue) else {
            throw Abort(.badRequest, reason: "Invalid \(key).")
        }
        return id
    }
}
