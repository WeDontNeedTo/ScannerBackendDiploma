import Fluent
import Vapor

struct UserItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let items = routes.grouped("user-items")
        items.get(use: index)
        items.post(use: create)
        items.post("return", use: `return`)
        items.group(":userItemID") { item in
            item.get(use: show)
            item.put(use: update)
            item.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [UserItem] {
        let user = try req.auth.require(User.self)
        let items = try await UserItem.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .with(\.$item)
            .all()
        try await req.audit(action: "read", entity: "user_items", message: "list")
        return items
    }

    func create(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        let payload = try req.content.decode(CreateUserItemRequest.self)
        if let existing = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == payload.itemID)
            .first() {
            if let id = try? user.requireID(), existing.$user.id == id {
                try await existing.save(on: req.db)
                try await req.audit(action: "update", entity: "user_items", entityID: existing.id)
                return existing
            }
            throw Abort(.conflict, reason: "Item is already grabbed by another user.")
        }
        let item = UserItem(userID: try user.requireID(), itemID: payload.itemID)
        try await item.save(on: req.db)
        try await req.audit(action: "create", entity: "user_items", entityID: item.id)
        return item
    }

    func show(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        let userItemID = try req.requireUUID("userItemID")
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .filter(\.$user.$id == user.requireID())
            .with(\.$item)
            .first() else {
            throw Abort(.notFound)
        }
        try await req.audit(action: "read", entity: "user_items", entityID: item.id)
        return item
    }

    func update(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        _ = try req.content.decode(UpdateUserItemRequest.self)
        let userItemID = try req.requireUUID("userItemID")
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw Abort(.notFound)
        }
        try await item.save(on: req.db)
        try await req.audit(action: "update", entity: "user_items", entityID: item.id)
        return item
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userItemID = try req.requireUUID("userItemID")
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw Abort(.notFound)
        }
        try await item.delete(on: req.db)
        try await req.audit(action: "delete", entity: "user_items", entityID: userItemID)
        return .noContent
    }

    func `return`(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let payload = try req.content.decode(ReturnUserItemRequest.self)
        guard let _ = try await Item.find(payload.itemID, on: req.db) else {
            throw Abort(.notFound)
        }
        guard let grabbed = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == payload.itemID)
            .first() else {
            throw Abort(.notFound, reason: "Item is not grabbed.")
        }
        if let id = try? user.requireID(), grabbed.$user.id != id {
            throw Abort(.conflict, reason: "Item is grabbed by another user.")
        }
        try await grabbed.delete(on: req.db)
        try await req.audit(action: "return", entity: "user_items", entityID: grabbed.id)
        return .ok
    }
}

struct CreateUserItemRequest: Content {
    let itemID: UUID
}

struct UpdateUserItemRequest: Content {
}

struct ReturnUserItemRequest: Content {
    let itemID: UUID
}
