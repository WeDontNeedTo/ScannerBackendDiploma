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

    func list(page: Int, per: Int, on db: Database) async throws -> [User] {
        let offset = (page - 1) * per
        return try await User.query(on: db)
            .sort(\.$fullName, .ascending)
            .range(offset..<(offset + per))
            .all()
    }

    func count(on db: Database) async throws -> Int {
        try await User.query(on: db).count()
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
