import Fluent
import Foundation

protocol ItemLocationRequestRepository {
    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest?
    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest?
    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest]
    func save(_ request: ItemLocationRequest, on db: Database) async throws
}
