import Fluent
import Foundation

struct FluentBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool {
        try await BrokenItem.query(on: db)
            .filter(\.$item.$id == itemID)
            .filter(\.$quantity > 0)
            .first() != nil
    }

    func save(_ brokenItem: BrokenItem, on db: Database) async throws {
        try await brokenItem.save(on: db)
    }
}
