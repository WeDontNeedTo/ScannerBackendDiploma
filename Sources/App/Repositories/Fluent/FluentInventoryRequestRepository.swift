import Fluent
import Foundation

struct FluentInventoryRequestRepository: InventoryRequestRepository {
    func create(_ request: InventoryRequest, on db: Database) async throws {
        try await request.save(on: db)
    }

    func find(id: UUID, on db: Database) async throws -> InventoryRequest? {
        try await InventoryRequest.query(on: db)
            .filter(\.$id == id)
            .first()
    }

    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest? {
        try await InventoryRequest.query(on: db)
            .filter(\.$id == id)
            .with(\.$items)
            .first()
    }

    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest] {
        try await InventoryRequest.query(on: db)
            .filter(\.$materiallyResponsibleUser.$id == materiallyResponsibleUserID)
            .filter(\.$status == .submitted)
            .with(\.$items)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest] {
        try await InventoryRequest.query(on: db)
            .filter(\.$requester.$id == requesterUserID)
            .with(\.$items)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func save(_ request: InventoryRequest, on db: Database) async throws {
        try await request.save(on: db)
    }

    func findActiveConflictingItemIDs(
        itemIDs: [UUID],
        excludingRequestID: UUID?,
        on db: Database
    ) async throws -> Set<UUID> {
        guard !itemIDs.isEmpty else {
            return []
        }

        var query = InventoryRequestItem.query(on: db)
            .filter(\.$item.$id ~~ itemIDs)
            .join(InventoryRequest.self, on: \InventoryRequest.$id == \InventoryRequestItem.$request.$id)
            .group(.or) { group in
                group.filter(InventoryRequest.self, \.$status == .draft)
                group.filter(InventoryRequest.self, \.$status == .submitted)
                group.filter(InventoryRequest.self, \.$status == .mrpCompletedSuccess)
                group.filter(InventoryRequest.self, \.$status == .mrpCompletedMissing)
            }

        if let excludingRequestID {
            query = query.filter(InventoryRequest.self, \.$id != excludingRequestID)
        }

        let rows = try await query.all()
        return Set(rows.map { $0.$item.id })
    }
}
