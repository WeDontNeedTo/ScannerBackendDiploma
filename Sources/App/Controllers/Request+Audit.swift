import Foundation
import Vapor

extension Request {
    func audit(
        action: String,
        entity: String,
        entityID: UUID? = nil,
        message: String? = nil,
        metadata: [String: String] = [:]
    ) async throws {
        var payload = metadata
        if let user = auth.get(User.self), let userID = user.id {
            payload["user_id"] = userID.uuidString
        }
        payload["path"] = url.path

        let metadataString: String?
        if payload.isEmpty {
            metadataString = nil
        } else {
            let data = try JSONEncoder().encode(payload)
            metadataString = String(data: data, encoding: .utf8)
        }

        let log = AuditLog(
            action: action,
            entity: entity,
            entityID: entityID,
            message: message,
            metadata: metadataString
        )
        try await log.save(on: db)
    }
}
