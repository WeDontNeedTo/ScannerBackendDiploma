import Fluent
import Foundation

protocol UserRepository {
    func find(id: UUID, on db: Database) async throws -> User?
    func findByLogin(_ login: String, on db: Database) async throws -> User?
    func list(page: Int, per: Int, on db: Database) async throws -> [User]
    func count(on db: Database) async throws -> Int
    func listMateriallyResponsible(on db: Database) async throws -> [User]
    func save(_ user: User, on db: Database) async throws
}
