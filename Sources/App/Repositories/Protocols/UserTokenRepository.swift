import Fluent
import Foundation

protocol UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws
    func deleteByUserID(_ userID: UUID, on db: Database) async throws
}
