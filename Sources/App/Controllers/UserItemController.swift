import Fluent
import Vapor

struct UserItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let items = routes.grouped("user-items")
        items.get(use: index)
        items.get("incoming", use: incoming)
        items.post(use: create)
        items.post("return", use: `return`)
        items.post("transfer-request", use: transferRequest)
        items.post("transfer", use: transfer)
        items.group(":userItemID") { item in
            item.get(use: show)
            item.post("approve", use: approve)
            item.put(use: update)
            item.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [UserItem] {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        var query = UserItem.query(on: req.db)
            .with(\.$item)
        if !user.canApproveGrabRequests {
            query = query.filter(\.$user.$id == userID)
        }
        let items = try await query.all()
        try await req.audit(action: "read", entity: "user_items", message: "list")
        return items
    }

    func incoming(req: Request) async throws -> [UserItem] {
        let user = try req.auth.require(User.self)
        try user.requireInventoryManagerRole()
        let userID = try user.requireID()
        let requests = try await UserItem.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$status == .requested)
                group.filter(\.$status == .transferRequested)
            }
            .filter(\.$requestedToUserID == userID)
            .with(\.$item)
            .with(\.$user)
            .all()
        try await req.audit(action: "read", entity: "user_items", message: "incoming_requests")
        return requests
    }

    func create(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        let payload = try req.content.decode(CreateUserItemRequest.self)
        let userID = try user.requireID()
        guard let itemModel = try await Item.find(payload.itemID, on: req.db) else {
            throw Abort(.notFound, reason: "Item not found.")
        }
        guard itemModel.$responsibleUser.id != nil else {
            throw Abort(.conflict, reason: "Item has no materially responsible person assigned.")
        }
        if let existing = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == payload.itemID)
            .first() {
            if existing.$user.id == userID {
                try await existing.save(on: req.db)
                try await req.audit(action: "update", entity: "user_items", entityID: existing.id)
                return existing
            }
            throw Abort(.conflict, reason: "Item is already grabbed by another user.")
        }
        let requestedToUserID = try await resolveRequestedToUserID(
            requestedToUserID: payload.requestedToUserID,
            fallbackResponsibleUserID: itemModel.$responsibleUser.id,
            requester: user,
            db: req.db
        )
        let status: UserItemStatus = user.canBypassRequestFlow ? .approved : .requested
        let item = UserItem(
            userID: userID,
            itemID: payload.itemID,
            status: status,
            approvedByUserID: user.canBypassRequestFlow ? userID : nil,
            requestedToUserID: user.canBypassRequestFlow ? nil : requestedToUserID
        )
        if status == .approved {
            item.grabbedAt = Date()
        }
        try await item.save(on: req.db)
        try await req.audit(action: "create", entity: "user_items", entityID: item.id)
        return item
    }

    func show(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        let userItemID = try req.requireUUID("userItemID")
        let userID = try user.requireID()
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .with(\.$item)
            .first()
        else {
            throw Abort(.notFound)
        }
        if !user.canApproveGrabRequests && item.$user.id != userID {
            throw Abort(.forbidden, reason: "You can only access your own item requests.")
        }
        try await req.audit(action: "read", entity: "user_items", entityID: item.id)
        return item
    }

    func approve(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        guard user.canApproveGrabRequests else {
            throw Abort(.forbidden, reason: "Only materially responsible person, accountant, or admin can approve requests.")
        }
        let userItemID = try req.requireUUID("userItemID")
        let approverID = try user.requireID()
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .first()
        else {
            throw Abort(.notFound)
        }
        guard item.status == .requested || item.status == .transferRequested else {
            throw Abort(.conflict, reason: "Only requested items can be approved.")
        }
        if !user.canBypassRequestFlow && item.requestedToUserID != approverID {
            throw Abort(.forbidden, reason: "This request is assigned to another user.")
        }
        if item.status == .transferRequested {
            guard let targetUserID = item.requestedToUserID else {
                throw Abort(.conflict, reason: "Transfer request has no target user.")
            }
            item.$user.id = targetUserID
            guard let itemModel = try await Item.find(item.$item.id, on: req.db) else {
                throw Abort(.notFound, reason: "Item not found.")
            }
            itemModel.$responsibleUser.id = targetUserID
            try await itemModel.save(on: req.db)
        }
        item.status = .approved
        item.approvedByUserID = approverID
        item.requestedToUserID = nil
        item.grabbedAt = Date()
        try await item.save(on: req.db)
        try await req.audit(action: "approve", entity: "user_items", entityID: item.id)
        return item
    }

    func update(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        _ = try req.content.decode(UpdateUserItemRequest.self)
        let userItemID = try req.requireUUID("userItemID")
        let userID = try user.requireID()
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .first()
        else {
            throw Abort(.notFound)
        }
        if !user.canApproveGrabRequests && item.$user.id != userID {
            throw Abort(.forbidden, reason: "You can only update your own request.")
        }
        try await item.save(on: req.db)
        try await req.audit(action: "update", entity: "user_items", entityID: item.id)
        return item
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let userItemID = try req.requireUUID("userItemID")
        let userID = try user.requireID()
        guard let item = try await UserItem.query(on: req.db)
            .filter(\.$id == userItemID)
            .first()
        else {
            throw Abort(.notFound)
        }
        if !user.canApproveGrabRequests && item.$user.id != userID {
            throw Abort(.forbidden, reason: "You can only delete your own request.")
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
        let userID = try user.requireID()
        if !user.canApproveGrabRequests && grabbed.$user.id != userID {
            throw Abort(.conflict, reason: "Item is grabbed by another user.")
        }
        try await grabbed.delete(on: req.db)
        try await req.audit(action: "return", entity: "user_items", entityID: grabbed.id)
        return .ok
    }

    func transfer(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        guard user.canBypassRequestFlow else {
            throw Abort(.forbidden, reason: "Direct transfer is available only for accountant or admin.")
        }
        let payload = try req.content.decode(TransferUserItemRequest.self)
        _ = try await requireMateriallyResponsibleUser(payload.toUserID, on: req.db)
        guard let grabbed = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == payload.itemID)
            .first()
        else {
            throw Abort(.notFound, reason: "Item is not assigned.")
        }
        guard grabbed.$user.id != payload.toUserID else {
            throw Abort(.badRequest, reason: "Item is already assigned to this user.")
        }
        grabbed.$user.id = payload.toUserID
        grabbed.status = .approved
        grabbed.approvedByUserID = try user.requireID()
        grabbed.requestedToUserID = nil
        grabbed.grabbedAt = Date()
        try await grabbed.save(on: req.db)
        if let itemModel = try await Item.find(payload.itemID, on: req.db) {
            itemModel.$responsibleUser.id = payload.toUserID
            try await itemModel.save(on: req.db)
        }
        try await req.audit(action: "transfer", entity: "user_items", entityID: grabbed.id)
        return grabbed
    }

    func transferRequest(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        try user.requireInventoryManagerRole()
        let payload = try req.content.decode(TransferUserItemRequest.self)
        let userID = try user.requireID()
        let targetUser = try await requireMateriallyResponsibleUser(payload.toUserID, on: req.db)
        guard let grabbed = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == payload.itemID)
            .first()
        else {
            throw Abort(.notFound, reason: "Item is not assigned.")
        }
        guard grabbed.$user.id == userID || user.canBypassRequestFlow else {
            throw Abort(.forbidden, reason: "Only current owner, accountant, or admin can request transfer.")
        }
        guard let targetUserId = try? targetUser.requireID(), grabbed.$user.id != targetUserId else {
            throw Abort(.badRequest, reason: "Item is already assigned to this user.")
        }
        grabbed.status = .transferRequested
        grabbed.approvedByUserID = nil
        grabbed.requestedToUserID = try targetUser.requireID()
        try await grabbed.save(on: req.db)
        try await req.audit(action: "transfer_request", entity: "user_items", entityID: grabbed.id)
        return grabbed
    }
}

struct CreateUserItemRequest: Content {
    let itemID: UUID
    let requestedToUserID: UUID?
}

struct UpdateUserItemRequest: Content {
}

struct ReturnUserItemRequest: Content {
    let itemID: UUID
}

struct TransferUserItemRequest: Content {
    let itemID: UUID
    let toUserID: UUID
}

extension UserItemController {
    fileprivate func requireMateriallyResponsibleUser(_ userID: UUID, on db: Database) async throws
        -> User
    {
        guard let user = try await User.find(userID, on: db) else {
            throw Abort(.notFound, reason: "Target user not found.")
        }
        guard user.role == .materiallyResponsiblePerson else {
            throw Abort(.badRequest, reason: "Target user must be materially_responsible_person.")
        }
        return user
    }

    fileprivate func resolveRequestedToUserID(
        requestedToUserID: UUID?,
        fallbackResponsibleUserID: UUID?,
        requester: User,
        db: Database
    ) async throws -> UUID {
        if requester.canBypassRequestFlow {
            return try requester.requireID()
        }
        let targetID = requestedToUserID ?? fallbackResponsibleUserID
        guard let resolvedTargetID = targetID else {
            throw Abort(.badRequest, reason: "requestedToUserID is required for request flow.")
        }
        _ = try await requireMateriallyResponsibleUser(resolvedTargetID, on: db)
        return resolvedTargetID
    }
}
