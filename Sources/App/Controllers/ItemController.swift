import Foundation
import Vapor

struct ItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let items = routes.grouped("items")
        items.get(use: index)
        items.post(use: create)
        items.get("available_filters", use: availableFilters)
        items.get("search", use: search)
        items.post("search", use: searchByBody)
        items.group(":itemID") { item in
            item.get(use: show)
            item.get("journal", use: journal)
            item.get("available_actions", use: availableActions)
            item.post("location", use: setLocation)
            item.post("grab", use: grab)
            item.post("broken", use: moveToBroken)
            item.put(use: update)
            item.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [Item] {
        do {
            let items = try await req.application.services.itemService.index(context: context(req))
            try await req.audit(action: "read", entity: "items", message: "list")
            return items
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func create(req: Request) async throws -> Item {
        do {
            let payload = try req.content.decode(CreateItemRequest.self)
            let item = try await req.application.services.itemService.create(
                data: ItemCreateData(
                    number: payload.number,
                    name: payload.name,
                    description: payload.description,
                    priceRub: payload.priceRub,
                    categoryID: payload.categoryID,
                    responsibleUserID: payload.responsibleUserID
                ),
                context: context(req)
            )
            try await req.audit(action: "create", entity: "items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func show(req: Request) async throws -> ItemScanResponse {
        do {
            let itemID = try req.requireUUID("itemID")
            let response = try await req.application.services.itemService.show(
                itemID: itemID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "items", entityID: response.item.id, message: "full")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func search(req: Request) async throws -> [ItemScanResponse] {
        do {
            let query = try req.query.decode(ItemSearchQuery.self)
            let responses = try await req.application.services.itemService.search(
                data: ItemSearchData(
                    query: query.query,
                    name: query.name,
                    number: query.number,
                    responsibleUserID: query.responsibleUserID,
                    page: query.page,
                    per: query.per
                ),
                context: context(req)
            )
            try await req.audit(action: "read", entity: "items", message: "search")
            return responses
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func searchByBody(req: Request) async throws -> [ItemScanResponse] {
        do {
            let query = try req.content.decode(ItemSearchQuery.self)
            let responses = try await req.application.services.itemService.search(
                data: ItemSearchData(
                    query: query.query,
                    name: query.name,
                    number: query.number,
                    responsibleUserID: query.responsibleUserID,
                    page: query.page,
                    per: query.per
                ),
                context: context(req)
            )
            try await req.audit(action: "read", entity: "items", message: "search")
            return responses
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func availableFilters(req: Request) async throws -> ItemAvailableFiltersResponse {
        do {
            let response = try await req.application.services.itemService.availableFilters(
                context: context(req)
            )
            try await req.audit(action: "read", entity: "items", message: "available_filters")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func setLocation(req: Request) async throws -> ItemLocation {
        do {
            let payload = try req.content.decode(SetItemLocationRequest.self)
            let itemID = try req.requireUUID("itemID")
            let result = try await req.application.services.itemService.setLocation(
                data: ItemSetLocationData(
                    itemID: itemID,
                    locationID: payload.locationID,
                    responsibleUserID: payload.responsibleUserID
                ),
                context: context(req)
            )

            let action = result.kind == .create ? "create" : "update"
            try await req.audit(action: action, entity: "item_locations", entityID: result.value.id)
            return result.value
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func availableActions(req: Request) async throws -> ItemAvailableActionsResponse {
        do {
            let itemID = try req.requireUUID("itemID")
            let response = try await req.application.services.itemService.availableActions(
                itemID: itemID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "items", entityID: itemID, message: "available_actions")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func journal(req: Request) async throws -> ItemJournalPageResponse {
        do {
            let itemID = try req.requireUUID("itemID")
            let query = try req.query.decode(ItemJournalQuery.self)
            let response = try await req.application.services.itemJournalService.list(
                itemID: itemID,
                page: query.page,
                per: query.per,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "item_journal_events", entityID: itemID, message: "journal")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func grab(req: Request) async throws -> UserItem {
        do {
            let payload = try req.content.decode(GrabItemRequest.self)
            let itemID = try req.requireUUID("itemID")
            let result = try await req.application.services.itemService.grab(
                data: ItemGrabData(itemID: itemID, requestedToUserID: payload.requestedToUserID),
                context: context(req)
            )
            let action = result.kind == .create ? "create" : "update"
            try await req.audit(action: action, entity: "user_items", entityID: result.value.id)
            return result.value
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func moveToBroken(req: Request) async throws -> BrokenItem {
        do {
            let payload = try req.content.decode(MoveItemToBrokenRequest.self)
            let itemID = try req.requireUUID("itemID")
            let broken = try await req.application.services.itemService.moveToBroken(
                data: ItemMoveToBrokenData(
                    itemID: itemID,
                    locationID: payload.locationID,
                    quantity: payload.quantity,
                    reason: payload.reason,
                    notes: payload.notes
                ),
                context: context(req)
            )
            try await req.audit(action: "create", entity: "broken_items", entityID: broken.id)
            return broken
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func update(req: Request) async throws -> Item {
        do {
            let payload = try req.content.decode(UpdateItemRequest.self)
            let itemID = try req.requireUUID("itemID")
            let item = try await req.application.services.itemService.update(
                data: ItemUpdateData(
                    itemID: itemID,
                    number: payload.number,
                    name: payload.name,
                    description: payload.description,
                    priceRub: payload.priceRub,
                    categoryID: payload.categoryID,
                    responsibleUserID: payload.responsibleUserID
                ),
                context: context(req)
            )
            try await req.audit(action: "update", entity: "items", entityID: item.id)
            return item
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        do {
            let itemID = try req.requireUUID("itemID")
            try await req.application.services.itemService.delete(itemID: itemID, context: context(req))
            try await req.audit(action: "delete", entity: "items", entityID: itemID)
            return .noContent
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}
