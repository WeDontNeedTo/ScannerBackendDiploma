import Fluent
import Foundation

protocol ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation?
    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation]
    func save(_ itemLocation: ItemLocation, on db: Database) async throws
}
