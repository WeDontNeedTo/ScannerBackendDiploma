import Fluent
import Foundation

struct FluentItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] {
        try await ItemCategory.query(on: db).all()
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
