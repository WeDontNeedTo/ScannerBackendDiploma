import Fluent
import Foundation

protocol BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool
    func listWithItem(on db: Database) async throws -> [BrokenItem]
    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem]
    func save(_ brokenItem: BrokenItem, on db: Database) async throws
}
