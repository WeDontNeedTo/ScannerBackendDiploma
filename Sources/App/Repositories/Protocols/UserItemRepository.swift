import Fluent
import Foundation

protocol UserItemRepository {
    func listForUser(userID: UUID, on db: Database) async throws -> [UserItem]
    func listApprovedForUser(userID: UUID, on db: Database) async throws -> [UserItem]
    func listAllWithItem(on db: Database) async throws -> [UserItem]
    func listIncoming(for userID: UUID, on db: Database) async throws -> [UserItem]
    func find(id: UUID, on db: Database) async throws -> UserItem?
    func findWithItem(id: UUID, on db: Database) async throws -> UserItem?
    func findByItemID(itemID: UUID, on db: Database) async throws -> UserItem?
    func findByItemIDWithUser(itemID: UUID, on db: Database) async throws -> UserItem?
    func save(_ userItem: UserItem, on db: Database) async throws
    func delete(_ userItem: UserItem, on db: Database) async throws
}

extension UserItemRepository {
    func listApprovedForUser(userID: UUID, on db: Database) async throws -> [UserItem] {
        try await listForUser(userID: userID, on: db)
            .filter { $0.status == .approved }
    }
}
