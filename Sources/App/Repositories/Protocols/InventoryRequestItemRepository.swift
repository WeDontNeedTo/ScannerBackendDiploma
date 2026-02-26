import Fluent
import Foundation

protocol InventoryRequestItemRepository {
    func create(_ item: InventoryRequestItem, on db: Database) async throws
    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem?
    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem]
    func deleteByRequestID(requestID: UUID, on db: Database) async throws
    func save(_ item: InventoryRequestItem, on db: Database) async throws
}
