import Fluent
import Foundation

protocol ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter]
    func find(id: UUID, on db: Database) async throws -> ItemParameter?
    func save(_ parameter: ItemParameter, on db: Database) async throws
    func delete(_ parameter: ItemParameter, on db: Database) async throws
}
