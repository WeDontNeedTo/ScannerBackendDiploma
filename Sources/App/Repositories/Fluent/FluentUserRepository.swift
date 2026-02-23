import Fluent
import Foundation

struct FluentUserRepository: UserRepository {
    func find(id: UUID, on db: Database) async throws -> User? {
        try await User.find(id, on: db)
    }

    func findByLogin(_ login: String, on db: Database) async throws -> User? {
        try await User.query(on: db)
            .filter(\.$login == login)
            .first()
    }

    func listMateriallyResponsible(on db: Database) async throws -> [User] {
        try await User.query(on: db)
            .filter(\.$role == .materiallyResponsiblePerson)
            .sort(\.$fullName, .ascending)
            .all()
    }

    func save(_ user: User, on db: Database) async throws {
        try await user.save(on: db)
    }
}
