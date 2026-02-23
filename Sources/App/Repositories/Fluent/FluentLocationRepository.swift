import Fluent
import Foundation

struct FluentLocationRepository: LocationRepository {
    func list(on db: Database) async throws -> [Location] {
        try await Location.query(on: db).all()
    }

    func find(id: UUID, on db: Database) async throws -> Location? {
        try await Location.find(id, on: db)
    }

    func save(_ location: Location, on db: Database) async throws {
        try await location.save(on: db)
    }

    func delete(_ location: Location, on db: Database) async throws {
        try await location.delete(on: db)
    }
}
