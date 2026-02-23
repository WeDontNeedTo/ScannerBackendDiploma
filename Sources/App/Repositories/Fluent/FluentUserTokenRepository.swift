import Fluent
import Foundation

struct FluentUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {
        try await token.save(on: db)
    }

    func deleteByUserID(_ userID: UUID, on db: Database) async throws {
        try await UserToken.query(on: db)
            .filter(\.$user.$id == userID)
            .delete()
    }
}
