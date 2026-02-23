import Fluent
import Foundation

protocol ItemRepository {
    func listWithRelations(on db: Database) async throws -> [Item]
    func findWithRelations(id: UUID, on db: Database) async throws -> Item?
    func findWithRelations(number: String, on db: Database) async throws -> Item?
    func search(with data: ItemSearchData, on db: Database) async throws -> [Item]
    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats
    func find(id: UUID, on db: Database) async throws -> Item?
    func save(_ item: Item, on db: Database) async throws
    func delete(_ item: Item, on db: Database) async throws
}
