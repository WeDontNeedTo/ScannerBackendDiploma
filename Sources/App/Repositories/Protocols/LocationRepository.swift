import Fluent
import Foundation

protocol LocationRepository {
    func list(on db: Database) async throws -> [Location]
    func find(id: UUID, on db: Database) async throws -> Location?
    func save(_ location: Location, on db: Database) async throws
    func delete(_ location: Location, on db: Database) async throws
}
