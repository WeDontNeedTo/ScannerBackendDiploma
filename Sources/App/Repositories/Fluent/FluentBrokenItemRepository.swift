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

    func listWithItem(on db: Database) async throws -> [BrokenItem] {
        try await BrokenItem.query(on: db)
            .filter(\.$quantity > 0)
            .with(\.$item)
            .sort(\.$reportedAt, .descending)
            .all()
    }

    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem] {
        try await BrokenItem.query(on: db)
            .join(Item.self, on: \BrokenItem.$item.$id == \Item.$id)
            .filter(\.$quantity > 0)
            .filter(Item.self, \Item.$responsibleUser.$id == responsibleUserID)
            .with(\.$item)
            .sort(\.$reportedAt, .descending)
            .all()
    }
}
