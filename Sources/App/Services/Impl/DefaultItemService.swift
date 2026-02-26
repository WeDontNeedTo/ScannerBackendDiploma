import Fluent
import Foundation

struct DefaultItemService: ItemService {
    private let itemRepository: any ItemRepository
    private let userRepository: any UserRepository
    private let userItemRepository: any UserItemRepository
    private let itemLocationRepository: any ItemLocationRepository
    private let brokenItemRepository: any BrokenItemRepository
    private let itemCategoryRepository: any ItemCategoryRepository
    private let locationRepository: any LocationRepository
    private let itemJournalService: any ItemJournalService

    init(repositories: RepositoryContainer, itemJournalService: any ItemJournalService) {
        self.itemRepository = repositories.itemRepository
        self.userRepository = repositories.userRepository
        self.userItemRepository = repositories.userItemRepository
        self.itemLocationRepository = repositories.itemLocationRepository
        self.brokenItemRepository = repositories.brokenItemRepository
        self.itemCategoryRepository = repositories.itemCategoryRepository
        self.locationRepository = repositories.locationRepository
        self.itemJournalService = itemJournalService
    }

    func index(context: ServiceContext) async throws -> [Item] {
        try await itemRepository.listWithRelations(on: context.db)
    }

    func create(data: ItemCreateData, context: ServiceContext) async throws -> Item {
        let priceRub = try data.priceRub.map(normalizePriceRub)
        let responsibleUserID = try await requireMateriallyResponsibleUserID(data.responsibleUserID, on: context.db)

        if let categoryID = data.categoryID,
            !(try await itemCategoryRepository.exists(id: categoryID, on: context.db))
        {
            throw DomainError.notFound("Category not found.")
        }

        let item = Item(
            number: data.number,
            name: data.name,
            description: data.description,
            priceRub: priceRub,
            categoryID: data.categoryID,
            responsibleUserID: responsibleUserID
        )
        try await itemRepository.save(item, on: context.db)
        return item
    }

    func show(itemID: UUID, context: ServiceContext) async throws -> ItemScanResponse {
        guard let item = try await itemRepository.findWithRelations(id: itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        return try await buildItemScanResponse(item: item, context: context)
    }

    func search(data: ItemSearchData, context: ServiceContext) async throws -> [ItemScanResponse] {
        if let perValue = data.per, perValue <= 0 {
            throw DomainError.badRequest("Per must be greater than zero.")
        }
        if data.page != nil || data.per != nil {
            let page = data.page ?? 1
            let per = data.per ?? 50
            guard page > 0, per > 0 else {
                throw DomainError.badRequest("Page and per must be greater than zero.")
            }
        }

        let items = try await itemRepository.search(with: data, on: context.db)
        var responses: [ItemScanResponse] = []
        responses.reserveCapacity(items.count)
        for item in items {
            responses.append(try await buildItemScanResponse(item: item, context: context))
        }
        return responses
    }

    func availableFilters(context: ServiceContext) async throws -> ItemAvailableFiltersResponse {
        let users = try await userRepository.listMateriallyResponsible(on: context.db)
        let filters = users.map { user in
            ItemResponsibleUserFilter(id: user.id, fullName: user.fullName)
        }
        return ItemAvailableFiltersResponse(materiallyResponsiblePersons: filters)
    }

    func availableActions(itemID: UUID, context: ServiceContext) async throws -> ItemAvailableActionsResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let item = try await itemRepository.find(id: itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        let responsibleUserID = item.$responsibleUser.id
        let hasResponsibleUser = responsibleUserID != nil
        let isCurrentResponsiblePerson = responsibleUserID == userID
        let canUseDirectFlow = user.canBypassRequestFlow

        let existingGrab = try await userItemRepository.findByItemID(itemID: itemID, on: context.db)
        let grabbedByCurrentUser = existingGrab?.$user.id == userID && existingGrab?.status == .approved
        if grabbedByCurrentUser {
            return ItemAvailableActionsResponse(
                itemID: itemID,
                currentUserID: userID,
                currentUserRole: user.role,
                materiallyResponsiblePersonID: responsibleUserID,
                actions: ItemAvailableActionFlags(
                    grabDirect: false,
                    grabRequest: false,
                    setLocationDirect: false,
                    setLocationRequest: false,
                    moveToBroken: false,
                    returnItem: true
                ),
                availableActions: [.returnItem]
            )
        }
        let grabbedByAnotherUser = existingGrab != nil && existingGrab?.$user.id != userID

        let canGrabDirectly = canUseDirectFlow || isCurrentResponsiblePerson
        let grabDirect = hasResponsibleUser && !grabbedByAnotherUser && canGrabDirectly
        let grabRequest = hasResponsibleUser && !grabbedByAnotherUser && !grabDirect

        let setLocationDirect = canUseDirectFlow || isCurrentResponsiblePerson
        let setLocationRequest = !setLocationDirect && hasResponsibleUser

        let moveToBroken = user.role == .materiallyResponsiblePerson && isCurrentResponsiblePerson

        var availableActions: [ItemAvailableAction] = []
        if grabDirect {
            availableActions.append(.grabDirect)
        }
        if grabRequest {
            availableActions.append(.grabRequest)
        }
        if setLocationDirect {
            availableActions.append(.setLocationDirect)
        }
        if setLocationRequest {
            availableActions.append(.setLocationRequest)
        }
        if moveToBroken {
            availableActions.append(.moveToBroken)
        }

        return ItemAvailableActionsResponse(
            itemID: itemID,
            currentUserID: userID,
            currentUserRole: user.role,
            materiallyResponsiblePersonID: responsibleUserID,
            actions: ItemAvailableActionFlags(
                grabDirect: grabDirect,
                grabRequest: grabRequest,
                setLocationDirect: setLocationDirect,
                setLocationRequest: setLocationRequest,
                moveToBroken: moveToBroken,
                returnItem: false
            ),
            availableActions: availableActions
        )
    }

    func setLocation(data: ItemSetLocationData, context: ServiceContext) async throws -> OperationResult<ItemLocation> {
        let user = try requireCurrentUser(context)
        guard let item = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        let userID = try user.requireID()
        let canSetDirectly = user.canBypassRequestFlow || item.$responsibleUser.id == userID
        guard canSetDirectly else {
            throw DomainError.forbidden("Direct location change is allowed only for current responsible user, accountant, or admin.")
        }

        guard let location = try await locationRepository.find(id: data.locationID, on: context.db) else {
            throw DomainError.notFound("Location not found.")
        }

        let itemID = try item.requireID()
        let previousResponsibleUserID = item.$responsibleUser.id
        if let responsibleUserID = data.responsibleUserID {
            item.$responsibleUser.id = try await requireMateriallyResponsibleUserID(responsibleUserID, on: context.db)
            try await itemRepository.save(item, on: context.db)

            if previousResponsibleUserID != item.$responsibleUser.id {
                let actorName = user.fullName
                let itemLabel = ItemJournalMessageFactory.itemLabel(name: item.name, number: item.number)
                let oldResponsible = try await userDisplayName(userID: previousResponsibleUserID, db: context.db)
                let newResponsible = try await userDisplayName(userID: item.$responsibleUser.id, db: context.db)
                let message = ItemJournalMessageFactory.responsibleChanged(
                    actor: actorName,
                    itemLabel: itemLabel,
                    oldResponsible: oldResponsible,
                    newResponsible: newResponsible
                )
                try await itemJournalService.record(
                    data: ItemJournalRecordData(
                        itemID: itemID,
                        actorUserID: user.id,
                        eventType: ItemJournalEventType.responsibleChanged,
                        message: message
                    ),
                    context: context
                )
            }
        }

        if let existing = try await itemLocationRepository.find(
            itemID: data.itemID,
            locationID: data.locationID,
            on: context.db
        ) {
            try await itemLocationRepository.save(existing, on: context.db)
            try await recordLocationChange(
                actor: user,
                item: item,
                locationName: location.name,
                context: context
            )
            return OperationResult(value: existing, kind: .update)
        }

        let itemLocation = ItemLocation(itemID: data.itemID, locationID: data.locationID)
        try await itemLocationRepository.save(itemLocation, on: context.db)
        try await recordLocationChange(
            actor: user,
            item: item,
            locationName: location.name,
            context: context
        )
        return OperationResult(value: itemLocation, kind: .create)
    }

    func grab(data: ItemGrabData, context: ServiceContext) async throws -> OperationResult<UserItem> {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let item = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        guard item.$responsibleUser.id != nil else {
            throw DomainError.conflict("Item has no materially responsible person assigned.")
        }

        if let existing = try await userItemRepository.findByItemID(itemID: data.itemID, on: context.db) {
            if existing.$user.id == userID {
                try await userItemRepository.save(existing, on: context.db)
                return OperationResult(value: existing, kind: .update)
            }
            throw DomainError.conflict("Item is already grabbed by another user.")
        }

        let canApproveDirectly = user.canBypassRequestFlow || item.$responsibleUser.id == userID
        let requestedToUserID: UUID?
        if canApproveDirectly {
            requestedToUserID = nil
        } else {
            requestedToUserID = try await resolveRequestedToUserID(
                requestedToUserID: data.requestedToUserID,
                fallbackResponsibleUserID: item.$responsibleUser.id,
                requester: user,
                db: context.db
            )
        }

        let status: UserItemStatus = canApproveDirectly ? .approved : .requested
        let userItem = UserItem(
            userID: userID,
            itemID: data.itemID,
            status: status,
            approvedByUserID: canApproveDirectly ? userID : nil,
            requestedToUserID: requestedToUserID
        )
        if status == .approved {
            userItem.grabbedAt = Date()
        }
        try await userItemRepository.save(userItem, on: context.db)

        let itemLabel = ItemJournalMessageFactory.itemLabel(name: item.name, number: item.number)
        let message: String
        let eventType: String
        if status == .requested {
            let targetName = try await userDisplayName(userID: requestedToUserID, db: context.db)
            message = ItemJournalMessageFactory.grabRequested(
                actor: user.fullName,
                itemLabel: itemLabel,
                target: targetName
            )
            eventType = ItemJournalEventType.grabRequested
        } else {
            message = ItemJournalMessageFactory.grabApproved(actor: user.fullName, itemLabel: itemLabel)
            eventType = ItemJournalEventType.grabApproved
        }

        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: data.itemID,
                actorUserID: user.id,
                eventType: eventType,
                message: message
            ),
            context: context
        )
        return OperationResult(value: userItem, kind: .create)
    }

    func moveToBroken(data: ItemMoveToBrokenData, context: ServiceContext) async throws -> BrokenItem {
        let user = try requireCurrentUser(context)
        guard user.canManageInventory else {
            throw DomainError.forbidden("This action requires materially responsible person, accountant, or admin role.")
        }

        guard data.quantity > 0 else {
            throw DomainError.badRequest("Quantity must be greater than zero.")
        }

        guard let item = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        let location = try await locationRepository.find(id: data.locationID, on: context.db)
        guard location != nil else {
            throw DomainError.notFound("Location not found.")
        }

        let broken = BrokenItem(
            itemID: data.itemID,
            locationID: data.locationID,
            quantity: data.quantity,
            reportedAt: Date(),
            reason: data.reason,
            notes: data.notes
        )
        try await brokenItemRepository.save(broken, on: context.db)

        let actorName = user.fullName
        let itemLabel = ItemJournalMessageFactory.itemLabel(name: item.name, number: item.number)
        let locationName = location?.name ?? ItemJournalMessageFactory.unknownLocation()
        let message = ItemJournalMessageFactory.movedToBroken(
            actor: actorName,
            itemLabel: itemLabel,
            locationName: locationName,
            quantity: data.quantity,
            reason: data.reason,
            notes: data.notes
        )
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: data.itemID,
                actorUserID: user.id,
                eventType: ItemJournalEventType.movedToBroken,
                message: message
            ),
            context: context
        )
        return broken
    }

    func update(data: ItemUpdateData, context: ServiceContext) async throws -> Item {
        guard let item = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if let number = data.number {
            item.number = number
        }
        if let name = data.name {
            item.name = name
        }
        if data.description != nil {
            item.description = data.description
        }
        if let priceRub = data.priceRub {
            item.priceRub = try normalizePriceRub(priceRub)
        }
        if let responsibleUserID = data.responsibleUserID {
            item.$responsibleUser.id = try await requireMateriallyResponsibleUserID(
                responsibleUserID,
                on: context.db
            )
        }
        if let categoryID = data.categoryID {
            guard try await itemCategoryRepository.exists(id: categoryID, on: context.db) else {
                throw DomainError.notFound("Category not found.")
            }
            item.$category.id = categoryID
        }

        try await itemRepository.save(item, on: context.db)
        return item
    }

    func delete(itemID: UUID, context: ServiceContext) async throws {
        guard let item = try await itemRepository.find(id: itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        try await itemRepository.delete(item, on: context.db)
    }
}

extension DefaultItemService {
    private func requireCurrentUser(_ context: ServiceContext) throws -> User {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        return user
    }

    private func resolveRequestedToUserID(
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
            throw DomainError.badRequest("requestedToUserID is required for request flow.")
        }
        guard let targetUser = try await userRepository.find(id: resolvedTargetID, on: db) else {
            throw DomainError.notFound("Requested approver not found.")
        }
        guard targetUser.role == .materiallyResponsiblePerson else {
            throw DomainError.badRequest("Requested approver must have materially_responsible_person role.")
        }
        return resolvedTargetID
    }

    private func requireMateriallyResponsibleUserID(_ userID: UUID, on db: Database) async throws -> UUID {
        guard let user = try await userRepository.find(id: userID, on: db) else {
            throw DomainError.notFound("Responsible user not found.")
        }
        guard user.role == .materiallyResponsiblePerson else {
            throw DomainError.badRequest("Responsible user must have materially_responsible_person role.")
        }
        return userID
    }

    private func normalizePriceRub(_ priceRub: Decimal) throws -> Decimal {
        guard priceRub >= Decimal.zero else {
            throw DomainError.badRequest("Price must be zero or greater.")
        }
        var mutableValue = priceRub
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &mutableValue, 2, .plain)
        guard rounded == priceRub else {
            throw DomainError.badRequest("priceRub supports up to 2 decimal places.")
        }
        return rounded
    }

    private func buildItemScanResponse(item: Item, context: ServiceContext) async throws -> ItemScanResponse {
        let itemID = try item.requireID()

        let categoryName: String?
        if let categoryID = item.$category.id,
            let category = try await itemCategoryRepository.find(id: categoryID, on: context.db)
        {
            categoryName = category.name
        } else {
            categoryName = nil
        }

        let itemLocations = try await itemLocationRepository.listByItemWithLocation(itemID: itemID, on: context.db)
        let sortedLocations = itemLocations.sorted { lhs, rhs in
            let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? Date.distantPast
            let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? Date.distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return (lhs.id?.uuidString ?? "") > (rhs.id?.uuidString ?? "")
        }
        let currentLocation = sortedLocations.first.map { ItemCurrentLocationInfo(location: $0.location) }

        let isBroken = try await brokenItemRepository.hasPositiveQuantity(itemID: itemID, on: context.db)

        let grabbedItem = try await userItemRepository.findByItemIDWithUser(itemID: itemID, on: context.db)
        let approvedGrab = grabbedItem?.status == .approved ? grabbedItem : nil

        let grabbedBy = approvedGrab.map { userItem in
            UserGrabInfo(
                user: userItem.user.asPublic(),
                name: userItem.user.fullName,
                grabbedAt: userItem.grabbedAt
            )
        }

        let responsibleUser: ItemResponsibleUserResponse?
        if let responsibleUserID = item.$responsibleUser.id {
            if let user = try await userRepository.find(id: responsibleUserID, on: context.db) {
                responsibleUser = ItemResponsibleUserResponse(id: user.id, fullName: user.fullName)
            } else {
                responsibleUser = ItemResponsibleUserResponse(
                    id: responsibleUserID,
                    fullName: ItemJournalMessageFactory.unknownUser()
                )
            }
        } else {
            responsibleUser = nil
        }

        let itemResponse = ItemResponse(
            id: item.id,
            number: item.number,
            name: item.name,
            description: item.description,
            priceRub: item.priceRub,
            responsibleUser: responsibleUser,
            parameters: item.parameters
        )

        return ItemScanResponse(
            item: itemResponse,
            categoryName: categoryName,
            locations: [],
            currentLocation: currentLocation,
            isBroken: isBroken,
            isGrabbed: grabbedBy != nil,
            grabbedBy: grabbedBy
        )
    }

    private func userDisplayName(userID: UUID?, db: Database) async throws -> String {
        guard let userID else {
            return ItemJournalMessageFactory.unknownUser()
        }
        guard let user = try await userRepository.find(id: userID, on: db) else {
            return ItemJournalMessageFactory.unknownUser()
        }
        return user.fullName
    }

    private func recordLocationChange(
        actor: User,
        item: Item,
        locationName: String,
        context: ServiceContext
    ) async throws {
        let itemID = try item.requireID()
        let message = ItemJournalMessageFactory.locationChanged(
            actor: actor.fullName,
            itemLabel: ItemJournalMessageFactory.itemLabel(name: item.name, number: item.number),
            locationName: locationName
        )
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: itemID,
                actorUserID: actor.id,
                eventType: ItemJournalEventType.locationChanged,
                message: message
            ),
            context: context
        )
    }
}
