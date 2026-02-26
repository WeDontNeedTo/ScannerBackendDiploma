import Fluent
import Foundation

protocol ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory]
    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount]
    func exists(id: UUID, on db: Database) async throws -> Bool
    func find(id: UUID, on db: Database) async throws -> ItemCategory?
    func save(_ category: ItemCategory, on db: Database) async throws
    func delete(_ category: ItemCategory, on db: Database) async throws
}
