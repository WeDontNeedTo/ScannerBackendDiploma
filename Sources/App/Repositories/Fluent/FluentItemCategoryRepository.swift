import Fluent
import Foundation

struct FluentItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] {
        try await ItemCategory.query(on: db).all()
    }

    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount] {
        let categories = try await ItemCategory.query(on: db)
            .sort(\.$name, .ascending)
            .all()
        let categoryIDs = try await Item.query(on: db).all(\.$category.$id)
        let countsByCategoryID = categoryIDs.compactMap { $0 }.reduce(into: [UUID: Int]()) { counts, categoryID in
            counts[categoryID, default: 0] += 1
        }

        return categories.map { category in
            let itemCount: Int
            if let categoryID = category.id {
                itemCount = countsByCategoryID[categoryID, default: 0]
            } else {
                itemCount = 0
            }

            return ItemCategoryItemsCount(
                categoryID: category.id,
                categoryName: category.name,
                itemsCount: itemCount
            )
        }
    }

    func exists(id: UUID, on db: Database) async throws -> Bool {
        try await ItemCategory.find(id, on: db) != nil
    }

    func find(id: UUID, on db: Database) async throws -> ItemCategory? {
        try await ItemCategory.find(id, on: db)
    }

    func save(_ category: ItemCategory, on db: Database) async throws {
        try await category.save(on: db)
    }

    func delete(_ category: ItemCategory, on db: Database) async throws {
        try await category.delete(on: db)
    }
}
