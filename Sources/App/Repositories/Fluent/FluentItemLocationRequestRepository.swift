import Fluent
import Foundation

struct FluentItemLocationRequestRepository: ItemLocationRequestRepository {
    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest? {
        try await ItemLocationRequest.query(on: db)
            .filter(\.$id == id)
            .with(\.$item)
            .with(\.$location)
            .with(\.$requester)
            .first()
    }

    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest? {
        try await ItemLocationRequest.query(on: db)
            .filter(\.$item.$id == itemID)
            .filter(\.$location.$id == locationID)
            .filter(\.$requester.$id == requesterUserID)
            .filter(\.$status == .requested)
            .first()
    }

    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest] {
        try await ItemLocationRequest.query(on: db)
            .filter(\.$requestedToUserID == userID)
            .filter(\.$status == .requested)
            .with(\.$item)
            .with(\.$location)
            .with(\.$requester)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func save(_ request: ItemLocationRequest, on db: Database) async throws {
        try await request.save(on: db)
    }
}
