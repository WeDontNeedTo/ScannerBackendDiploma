import Fluent
import Foundation

struct FluentUserItemRepository: UserItemRepository {
    func listForUser(userID: UUID, on db: Database) async throws -> [UserItem] {
        try await UserItem.query(on: db)
            .filter(\.$user.$id == userID)
            .with(\.$item)
            .all()
    }

    func listApprovedForUser(userID: UUID, on db: Database) async throws -> [UserItem] {
        try await UserItem.query(on: db)
            .filter(\.$user.$id == userID)
            .filter(\.$status == .approved)
            .with(\.$item)
            .all()
    }

    func listAllWithItem(on db: Database) async throws -> [UserItem] {
        try await UserItem.query(on: db)
            .with(\.$item)
            .all()
    }

    func listIncoming(for userID: UUID, on db: Database) async throws -> [UserItem] {
        try await UserItem.query(on: db)
            .group(.or) { group in
                group.filter(\.$status == .requested)
                group.filter(\.$status == .transferRequested)
            }
            .filter(\.$requestedToUserID == userID)
            .with(\.$item)
            .with(\.$user)
            .all()
    }

    func find(id: UUID, on db: Database) async throws -> UserItem? {
        try await UserItem.query(on: db)
            .filter(\.$id == id)
            .first()
    }

    func findWithItem(id: UUID, on db: Database) async throws -> UserItem? {
        try await UserItem.query(on: db)
            .filter(\.$id == id)
            .with(\.$item)
            .first()
    }

    func findByItemID(itemID: UUID, on db: Database) async throws -> UserItem? {
        try await UserItem.query(on: db)
            .filter(\.$item.$id == itemID)
            .first()
    }

    func findByItemIDWithUser(itemID: UUID, on db: Database) async throws -> UserItem? {
        try await UserItem.query(on: db)
            .filter(\.$item.$id == itemID)
            .with(\.$user)
            .first()
    }

    func save(_ userItem: UserItem, on db: Database) async throws {
        try await userItem.save(on: db)
    }

    func delete(_ userItem: UserItem, on db: Database) async throws {
        try await userItem.delete(on: db)
    }
}
