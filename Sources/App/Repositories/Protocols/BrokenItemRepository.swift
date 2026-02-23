import Fluent
import Foundation

protocol BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool
    func save(_ brokenItem: BrokenItem, on db: Database) async throws
}
