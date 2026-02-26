import Fluent
import Foundation

protocol ItemRepository {
    func listWithRelations(on db: Database) async throws -> [Item]
    func findWithRelations(id: UUID, on db: Database) async throws -> Item?
    func findWithRelations(number: String, on db: Database) async throws -> Item?
    func search(with data: ItemSearchData, on db: Database) async throws -> [Item]
    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats
    func countByResponsibleUser(responsibleUserID: UUID, on db: Database) async throws -> Int
    func listByResponsibleUserWithRelations(responsibleUserID: UUID, on db: Database) async throws -> [Item]
    func findAllByIDs(_ ids: [UUID], on db: Database) async throws -> [Item]
    func findAllByIDsWithRelations(_ ids: [UUID], on db: Database) async throws -> [Item]
    func saveAll(_ items: [Item], on db: Database) async throws
    func find(id: UUID, on db: Database) async throws -> Item?
    func save(_ item: Item, on db: Database) async throws
    func delete(_ item: Item, on db: Database) async throws
}
