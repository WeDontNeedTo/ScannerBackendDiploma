import Fluent
import Foundation

struct FluentItemLocationRepository: ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? {
        try await ItemLocation.query(on: db)
            .filter(\.$item.$id == itemID)
            .filter(\.$location.$id == locationID)
            .first()
    }

    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] {
        try await ItemLocation.query(on: db)
            .filter(\.$item.$id == itemID)
            .with(\.$location)
            .all()
    }

    func save(_ itemLocation: ItemLocation, on db: Database) async throws {
        try await itemLocation.save(on: db)
    }
}
