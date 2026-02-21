import Fluent
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
        items.get("detail", use: detail)
        items.group(":itemID") { item in
            item.get(use: show)
            item.get("scan", use: scan)
            item.post("location", use: setLocation)
            item.post("grab", use: grab)
            item.post("broken", use: moveToBroken)
            item.put(use: update)
            item.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [Item] {
        let items = try await Item.query(on: req.db)
            .with(\.$parameters)
            .with(\.$category)
            .all()
        try await req.audit(action: "read", entity: "items", message: "list")
        return items
    }

    func create(req: Request) async throws -> Item {
        let payload = try req.content.decode(CreateItemRequest.self)
        let priceRub = try payload.priceRub.map(normalizePriceRub)
        let responsibleUserID = try await requireMateriallyResponsibleUserID(
            payload.responsibleUserID,
            on: req.db
        )
        if let categoryID = payload.categoryID {
            guard (try await ItemCategory.find(categoryID, on: req.db)) != nil else {
                throw Abort(.notFound, reason: "Category not found.")
            }
        }
        let item = Item(
            number: payload.number,
            name: payload.name,
            description: payload.description,
            priceRub: priceRub,
            categoryID: payload.categoryID,
            responsibleUserID: responsibleUserID
        )
        try await item.save(on: req.db)
        try await req.audit(action: "create", entity: "items", entityID: item.id)
        return item
    }

    func show(req: Request) async throws -> Item {
        let itemID = try req.requireUUID("itemID")
        guard
            let item = try await Item.query(on: req.db)
                .filter(\.$id == itemID)
                .with(\.$parameters)
                .with(\.$category)
                .first()
        else {
            throw Abort(.notFound)
        }
        try await req.audit(action: "read", entity: "items", entityID: item.id)
        return item
    }

    func scan(req: Request) async throws -> ItemScanResponse {
        let itemID = try req.requireUUID("itemID")
        guard
            let item = try await Item.query(on: req.db)
                .filter(\.$id == itemID)
                .with(\.$parameters)
                .with(\.$category)
                .first()
        else {
            throw Abort(.notFound)
        }
        let response = try await buildItemScanResponse(req: req, item: item)
        try await req.audit(action: "scan", entity: "items", entityID: item.id)
        return response
    }

    func search(req: Request) async throws -> [ItemScanResponse] {
        let query = try req.query.decode(ItemSearchQuery.self)
        return try await search(req: req, query: query)
    }

    func searchByBody(req: Request) async throws -> [ItemScanResponse] {
        let query = try req.content.decode(ItemSearchQuery.self)
        return try await search(req: req, query: query)
    }

    func availableFilters(req: Request) async throws -> ItemAvailableFiltersResponse {
        let users = try await User.query(on: req.db)
            .filter(\.$role == .materiallyResponsiblePerson)
            .sort(\.$fullName, .ascending)
            .all()
        let filters = users.map { user in
            ItemResponsibleUserFilter(
                id: user.id,
                fullName: user.fullName
            )
        }
        try await req.audit(action: "read", entity: "items", message: "available_filters")
        return ItemAvailableFiltersResponse(materiallyResponsiblePersons: filters)
    }

    fileprivate func search(req: Request, query: ItemSearchQuery) async throws -> [ItemScanResponse] {
        let term = query.query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = query.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = query.number?.trimmingCharacters(in: .whitespacesAndNewlines)
        let responsibleUserID = query.responsibleUserID
        let per = query.per ?? 50

        let hasSearchCriteria =
            (term?.isEmpty == false) || (name?.isEmpty == false) || (number?.isEmpty == false)
            || responsibleUserID != nil
        if let perValue = query.per, perValue <= 0 {
            throw Abort(.badRequest, reason: "Per must be greater than zero.")
        }

        var itemsQuery = Item.query(on: req.db)
            .with(\.$parameters)
            .with(\.$category)

        if hasSearchCriteria {
            let page = query.page ?? 1
            if query.page != nil || query.per != nil {
                guard page > 0, per > 0 else {
                    throw Abort(.badRequest, reason: "Page and per must be greater than zero.")
                }
            }
            if let term, !term.isEmpty {
                itemsQuery = itemsQuery.group(.or) { group in
                    group.filter(\.$name, .custom("ILIKE"), "%\(term)%")
                    group.filter(\.$number, .custom("ILIKE"), "%\(term)%")
                }
            } else {
                if let name, !name.isEmpty {
                    itemsQuery = itemsQuery.filter(\.$name, .custom("ILIKE"), "%\(name)%")
                }
                if let number, !number.isEmpty {
                    itemsQuery = itemsQuery.filter(\.$number, .custom("ILIKE"), "%\(number)%")
                }
            }
            if let responsibleUserID {
                itemsQuery = itemsQuery.filter(\.$responsibleUser.$id == responsibleUserID)
            }
            if query.page != nil || query.per != nil {
                let offset = (page - 1) * per
                itemsQuery = itemsQuery.range(offset..<(offset + per))
            }
        } else {
            itemsQuery = itemsQuery.range(0..<per)
        }

        let items = try await itemsQuery.all()
        var responses: [ItemScanResponse] = []
        responses.reserveCapacity(items.count)
        for item in items {
            responses.append(try await buildItemScanResponse(req: req, item: item))
        }
        try await req.audit(action: "read", entity: "items", message: "search")
        return responses
    }

    func detail(req: Request) async throws -> ItemScanResponse {
        let query = try req.query.decode(ItemDetailQuery.self)
        let itemQuery = Item.query(on: req.db)
            .with(\.$parameters)
            .with(\.$category)

        let item: Item?
        if let itemID = query.id {
            item = try await itemQuery.filter(\.$id == itemID).first()
        } else if let number = query.number?.trimmingCharacters(in: .whitespacesAndNewlines),
            !number.isEmpty
        {
            item = try await itemQuery.filter(\.$number == number).first()
        } else {
            throw Abort(.badRequest, reason: "Provide id or number for item detail.")
        }

        guard let found = item else {
            throw Abort(.notFound)
        }

        let response = try await buildItemScanResponse(req: req, item: found)
        try await req.audit(action: "read", entity: "items", entityID: found.id, message: "detail")
        return response
    }

    func setLocation(req: Request) async throws -> ItemLocation {
        let user = try req.auth.require(User.self)
        try user.requireInventoryManagerRole()
        let payload = try req.content.decode(SetItemLocationRequest.self)
        let itemID = try req.requireUUID("itemID")
        guard let item = try await Item.find(itemID, on: req.db) else {
            throw Abort(.notFound)
        }
        guard (try await Location.find(payload.locationID, on: req.db)) != nil else {
            throw Abort(.notFound, reason: "Location not found.")
        }
        if let responsibleUserID = payload.responsibleUserID {
            item.$responsibleUser.id = try await requireMateriallyResponsibleUserID(
                responsibleUserID,
                on: req.db
            )
            try await item.save(on: req.db)
        }
        if let existing = try await ItemLocation.query(on: req.db)
            .filter(\.$item.$id == itemID)
            .filter(\.$location.$id == payload.locationID)
            .first()
        {
            try await existing.save(on: req.db)
            try await req.audit(action: "update", entity: "item_locations", entityID: existing.id)
            return existing
        }
        let itemLocation = ItemLocation(itemID: itemID, locationID: payload.locationID)
        try await itemLocation.save(on: req.db)
        try await req.audit(action: "create", entity: "item_locations", entityID: itemLocation.id)
        return itemLocation
    }

    func grab(req: Request) async throws -> UserItem {
        let user = try req.auth.require(User.self)
        let payload = try req.content.decode(GrabItemRequest.self)
        let userID = try user.requireID()
        let itemID = try req.requireUUID("itemID")
        guard let itemModel = try await Item.find(itemID, on: req.db) else {
            throw Abort(.notFound)
        }
        guard itemModel.$responsibleUser.id != nil else {
            throw Abort(.conflict, reason: "Item has no materially responsible person assigned.")
        }
        if let existing = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == itemID)
            .first()
        {
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
        let userItem = UserItem(
            userID: userID,
            itemID: itemID,
            status: status,
            approvedByUserID: user.canBypassRequestFlow ? userID : nil,
            requestedToUserID: user.canBypassRequestFlow ? nil : requestedToUserID
        )
        if status == .approved {
            userItem.grabbedAt = Date()
        }
        try await userItem.save(on: req.db)
        try await req.audit(action: "create", entity: "user_items", entityID: userItem.id)
        return userItem
    }

    func moveToBroken(req: Request) async throws -> BrokenItem {
        let user = try req.auth.require(User.self)
        try user.requireInventoryManagerRole()
        let payload = try req.content.decode(MoveItemToBrokenRequest.self)
        guard payload.quantity > 0 else {
            throw Abort(.badRequest, reason: "Quantity must be greater than zero.")
        }
        let itemID = try req.requireUUID("itemID")
        guard (try await Item.find(itemID, on: req.db)) != nil else {
            throw Abort(.notFound)
        }
        guard (try await Location.find(payload.locationID, on: req.db)) != nil else {
            throw Abort(.notFound, reason: "Location not found.")
        }
        let broken = BrokenItem(
            itemID: itemID,
            locationID: payload.locationID,
            quantity: payload.quantity,
            reportedAt: Date(),
            reason: payload.reason,
            notes: payload.notes
        )
        try await broken.save(on: req.db)
        try await req.audit(action: "create", entity: "broken_items", entityID: broken.id)
        return broken
    }

    func update(req: Request) async throws -> Item {
        let payload = try req.content.decode(UpdateItemRequest.self)
        let itemID = try req.requireUUID("itemID")
        guard let item = try await Item.find(itemID, on: req.db) else {
            throw Abort(.notFound)
        }
        if let number = payload.number {
            item.number = number
        }
        if let name = payload.name {
            item.name = name
        }
        if payload.description != nil {
            item.description = payload.description
        }
        if let priceRub = payload.priceRub {
            item.priceRub = try normalizePriceRub(priceRub)
        }
        if let responsibleUserID = payload.responsibleUserID {
            item.$responsibleUser.id = try await requireMateriallyResponsibleUserID(
                responsibleUserID,
                on: req.db
            )
        }
        if let categoryID = payload.categoryID {
            guard (try await ItemCategory.find(categoryID, on: req.db)) != nil else {
                throw Abort(.notFound, reason: "Category not found.")
            }
            item.$category.id = categoryID
        }
        try await item.save(on: req.db)
        try await req.audit(action: "update", entity: "items", entityID: item.id)
        return item
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let itemID = try req.requireUUID("itemID")
        guard let item = try await Item.find(itemID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await item.delete(on: req.db)
        try await req.audit(action: "delete", entity: "items", entityID: itemID)
        return .noContent
    }
}

struct CreateItemRequest: Content {
    let number: String
    let name: String
    let description: String?
    let priceRub: Decimal?
    let categoryID: UUID?
    let responsibleUserID: UUID
}

struct UpdateItemRequest: Content {
    let number: String?
    let name: String?
    let description: String?
    let priceRub: Decimal?
    let categoryID: UUID?
    let responsibleUserID: UUID?
}

struct ItemSearchQuery: Content {
    let query: String?
    let name: String?
    let number: String?
    let responsibleUserID: UUID?
    let page: Int?
    let per: Int?
}

struct ItemDetailQuery: Content {
    let id: UUID?
    let number: String?
}

struct SetItemLocationRequest: Content {
    let locationID: UUID
    let responsibleUserID: UUID?
}

struct GrabItemRequest: Content {
    let requestedToUserID: UUID?
}

struct MoveItemToBrokenRequest: Content {
    let locationID: UUID
    let quantity: Int
    let reason: String?
    let notes: String?
}

struct ItemScanResponse: Content {
    let item: Item
    let categoryName: String?
    let locations: [Location]
    let currentLocation: ItemCurrentLocationInfo?
    let isBroken: Bool
    let isGrabbed: Bool
    let grabbedBy: UserGrabInfo?
}

struct ItemCurrentLocationInfo: Content {
    let location: Location
}

struct UserGrabInfo: Content {
    let user: UserPublicResponse
    let name: String
    let grabbedAt: Date?
}

struct ItemResponsibleUserFilter: Content {
    let id: UUID?
    let fullName: String
}

struct ItemAvailableFiltersResponse: Content {
    let materiallyResponsiblePersons: [ItemResponsibleUserFilter]
}

extension ItemController {
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
        guard let targetUser = try await User.find(resolvedTargetID, on: db) else {
            throw Abort(.notFound, reason: "Requested approver not found.")
        }
        guard targetUser.role == .materiallyResponsiblePerson else {
            throw Abort(.badRequest, reason: "Requested approver must have materially_responsible_person role.")
        }
        return resolvedTargetID
    }

    fileprivate func requireMateriallyResponsibleUserID(_ userID: UUID, on db: Database) async throws
        -> UUID
    {
        guard let user = try await User.find(userID, on: db) else {
            throw Abort(.notFound, reason: "Responsible user not found.")
        }
        guard user.role == .materiallyResponsiblePerson else {
            throw Abort(.badRequest, reason: "Responsible user must have materially_responsible_person role.")
        }
        return userID
    }

    fileprivate func normalizePriceRub(_ priceRub: Decimal) throws -> Decimal {
        guard priceRub >= Decimal.zero else {
            throw Abort(.badRequest, reason: "Price must be zero or greater.")
        }
        var mutableValue = priceRub
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &mutableValue, 2, .plain)
        guard rounded == priceRub else {
            throw Abort(.badRequest, reason: "priceRub supports up to 2 decimal places.")
        }
        return rounded
    }

    fileprivate func buildItemScanResponse(req: Request, item: Item) async throws
        -> ItemScanResponse
    {
        let itemID = try item.requireID()
        let categoryName: String?
        if let categoryID = item.$category.id,
            let category = try await ItemCategory.find(categoryID, on: req.db)
        {
            categoryName = category.name
        } else {
            categoryName = nil
        }
        let itemLocations = try await ItemLocation.query(on: req.db)
            .filter(\.$item.$id == itemID)
            .with(\.$location)
            .all()
        let sortedLocations = itemLocations.sorted { lhs, rhs in
            let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? Date.distantPast
            let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? Date.distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return (lhs.id?.uuidString ?? "") > (rhs.id?.uuidString ?? "")
        }
        let currentItemLocation = sortedLocations.first
        let currentLocation = currentItemLocation.map {
            ItemCurrentLocationInfo(location: $0.location)
        }
        let isBroken =
            try await BrokenItem.query(on: req.db)
            .filter(\.$item.$id == itemID)
            .filter(\.$quantity > 0)
            .first() != nil
        let grabbedItem = try await UserItem.query(on: req.db)
            .filter(\.$item.$id == itemID)
            .filter(\.$status == .approved)
            .with(\.$user)
            .first()
        let grabbedBy = grabbedItem.map { item in
            UserGrabInfo(
                user: item.user.asPublic(),
                name: item.user.fullName,
                grabbedAt: item.grabbedAt
            )
        }
        let isGrabbed = grabbedBy != nil

        return ItemScanResponse(
            item: item,
            categoryName: categoryName,
            locations: [],
            currentLocation: currentLocation,
            isBroken: isBroken,
            isGrabbed: isGrabbed,
            grabbedBy: grabbedBy
        )
    }
}
