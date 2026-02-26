import Fluent
import Foundation

struct FluentInventoryRequestItemRepository: InventoryRequestItemRepository {
    func create(_ item: InventoryRequestItem, on db: Database) async throws {
        try await item.save(on: db)
    }

    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem? {
        try await InventoryRequestItem.query(on: db)
            .filter(\.$request.$id == requestID)
            .filter(\.$item.$id == itemID)
            .first()
    }

    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem] {
        try await InventoryRequestItem.query(on: db)
            .filter(\.$request.$id == requestID)
            .sort(\.$createdAt, .ascending)
            .all()
    }

    func deleteByRequestID(requestID: UUID, on db: Database) async throws {
        try await InventoryRequestItem.query(on: db)
            .filter(\.$request.$id == requestID)
            .delete()
    }

    func save(_ item: InventoryRequestItem, on db: Database) async throws {
        try await item.save(on: db)
    }
}
