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
        do {
            let items = try await req.application.services.userItemService.index(context: context(req))
            try await req.audit(action: "read", entity: "user_items", message: "list")
            return items
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func incoming(req: Request) async throws -> [UserItem] {
        do {
            let requests = try await req.application.services.userItemService.incoming(context: context(req))
            try await req.audit(action: "read", entity: "user_items", message: "incoming_requests")
            return requests
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func create(req: Request) async throws -> UserItem {
        do {
            let payload = try req.content.decode(CreateUserItemRequest.self)
            let result = try await req.application.services.userItemService.create(
                data: UserItemCreateData(itemID: payload.itemID, requestedToUserID: payload.requestedToUserID),
                context: context(req)
            )
            let action = result.kind == .create ? "create" : "update"
            try await req.audit(action: action, entity: "user_items", entityID: result.value.id)
            return result.value
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func show(req: Request) async throws -> UserItem {
        do {
            let userItemID = try req.requireUUID("userItemID")
            let item = try await req.application.services.userItemService.show(
                userItemID: userItemID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "user_items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func approve(req: Request) async throws -> UserItem {
        do {
            let userItemID = try req.requireUUID("userItemID")
            let item = try await req.application.services.userItemService.approve(
                data: UserItemApproveData(userItemID: userItemID),
                context: context(req)
            )
            try await req.audit(action: "approve", entity: "user_items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func update(req: Request) async throws -> UserItem {
        do {
            _ = try req.content.decode(UpdateUserItemRequest.self)
            let userItemID = try req.requireUUID("userItemID")
            let item = try await req.application.services.userItemService.update(
                data: UserItemUpdateData(userItemID: userItemID),
                context: context(req)
            )
            try await req.audit(action: "update", entity: "user_items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        do {
            let userItemID = try req.requireUUID("userItemID")
            try await req.application.services.userItemService.delete(
                data: UserItemDeleteData(userItemID: userItemID),
                context: context(req)
            )
            try await req.audit(action: "delete", entity: "user_items", entityID: userItemID)
            return .noContent
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func `return`(req: Request) async throws -> HTTPStatus {
        do {
            let payload = try req.content.decode(ReturnUserItemRequest.self)
            let entityID = try await req.application.services.userItemService.return(
                data: UserItemReturnData(itemID: payload.itemID),
                context: context(req)
            )
            try await req.audit(action: "return", entity: "user_items", entityID: entityID)
            return .ok
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func transfer(req: Request) async throws -> UserItem {
        do {
            let payload = try req.content.decode(TransferUserItemRequest.self)
            let item = try await req.application.services.userItemService.transfer(
                data: UserItemTransferData(itemID: payload.itemID, toUserID: payload.toUserID),
                context: context(req)
            )
            try await req.audit(action: "transfer", entity: "user_items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func transferRequest(req: Request) async throws -> UserItem {
        do {
            let payload = try req.content.decode(TransferUserItemRequest.self)
            let item = try await req.application.services.userItemService.transferRequest(
                data: UserItemTransferData(itemID: payload.itemID, toUserID: payload.toUserID),
                context: context(req)
            )
            try await req.audit(action: "transfer_request", entity: "user_items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}
