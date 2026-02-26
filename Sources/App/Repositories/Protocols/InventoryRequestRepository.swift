import Fluent
import Foundation

protocol InventoryRequestRepository {
    func create(_ request: InventoryRequest, on db: Database) async throws
    func find(id: UUID, on db: Database) async throws -> InventoryRequest?
    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest?
    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest]
    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest]
    func save(_ request: InventoryRequest, on db: Database) async throws
    func findActiveConflictingItemIDs(
        itemIDs: [UUID],
        excludingRequestID: UUID?,
        on db: Database
    ) async throws -> Set<UUID>
}
