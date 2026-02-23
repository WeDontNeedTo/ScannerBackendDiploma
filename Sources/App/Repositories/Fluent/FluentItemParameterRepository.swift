import Fluent
import Foundation

struct FluentItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] {
        try await ItemParameter.query(on: db).all()
    }

    func find(id: UUID, on db: Database) async throws -> ItemParameter? {
        try await ItemParameter.find(id, on: db)
    }

    func save(_ parameter: ItemParameter, on db: Database) async throws {
        try await parameter.save(on: db)
    }

    func delete(_ parameter: ItemParameter, on db: Database) async throws {
        try await parameter.delete(on: db)
    }
}
