import Fluent
import Foundation

struct DefaultUserItemService: UserItemService {
    private let itemRepository: any ItemRepository
    private let userRepository: any UserRepository
    private let userItemRepository: any UserItemRepository
    private let itemJournalService: any ItemJournalService

    init(repositories: RepositoryContainer, itemJournalService: any ItemJournalService) {
        self.itemRepository = repositories.itemRepository
        self.userRepository = repositories.userRepository
        self.userItemRepository = repositories.userItemRepository
        self.itemJournalService = itemJournalService
    }

    func index(context: ServiceContext) async throws -> [UserItem] {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        if user.canApproveGrabRequests {
            return try await userItemRepository.listAllWithItem(on: context.db)
        }
        return try await userItemRepository.listForUser(userID: userID, on: context.db)
    }

    func incoming(context: ServiceContext) async throws -> [UserItem] {
        let user = try requireCurrentUser(context)
        guard user.canManageInventory else {
            throw DomainError.forbidden("This action requires materially responsible person, accountant, or admin role.")
        }
        return try await userItemRepository.listIncoming(for: try user.requireID(), on: context.db)
    }

    func create(data: UserItemCreateData, context: ServiceContext) async throws -> OperationResult<UserItem> {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let itemModel = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound("Item not found.")
        }
        guard itemModel.$responsibleUser.id != nil else {
            throw DomainError.conflict("Item has no materially responsible person assigned.")
        }

        if let existing = try await userItemRepository.findByItemID(itemID: data.itemID, on: context.db) {
            if existing.$user.id == userID {
                try await userItemRepository.save(existing, on: context.db)
                return OperationResult(value: existing, kind: .update)
            }
            throw DomainError.conflict("Item is already grabbed by another user.")
        }

        let requestedToUserID = try await resolveRequestedToUserID(
            requestedToUserID: data.requestedToUserID,
            fallbackResponsibleUserID: itemModel.$responsibleUser.id,
            requester: user,
            db: context.db
        )

        let status: UserItemStatus = user.canBypassRequestFlow ? .approved : .requested
        let userItem = UserItem(
            userID: userID,
            itemID: data.itemID,
            status: status,
            approvedByUserID: user.canBypassRequestFlow ? userID : nil,
            requestedToUserID: user.canBypassRequestFlow ? nil : requestedToUserID
        )

        if status == .approved {
            userItem.grabbedAt = Date()
        }

        try await userItemRepository.save(userItem, on: context.db)

        let itemLabel = ItemJournalMessageFactory.itemLabel(name: itemModel.name, number: itemModel.number)
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

    func show(userItemID: UUID, context: ServiceContext) async throws -> UserItem {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let item = try await userItemRepository.findWithItem(id: userItemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if !user.canApproveGrabRequests && item.$user.id != userID {
            throw DomainError.forbidden("You can only access your own item requests.")
        }

        return item
    }

    func approve(data: UserItemApproveData, context: ServiceContext) async throws -> UserItem {
        let user = try requireCurrentUser(context)
        guard user.canApproveGrabRequests else {
            throw DomainError.forbidden("Only materially responsible person, accountant, or admin can approve requests.")
        }

        let approverID = try user.requireID()
        guard let item = try await userItemRepository.find(id: data.userItemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        guard item.status == .requested || item.status == .transferRequested else {
            throw DomainError.conflict("Only requested items can be approved.")
        }

        if !user.canBypassRequestFlow && item.requestedToUserID != approverID {
            throw DomainError.forbidden("This request is assigned to another user.")
        }

        let statusBeforeApprove = item.status
        let transferTargetUserID = item.requestedToUserID
        let sourceOwnerUserID = item.$user.id
        if item.status == .transferRequested {
            guard let targetUserID = item.requestedToUserID else {
                throw DomainError.conflict("Transfer request has no target user.")
            }
            item.$user.id = targetUserID

            guard let itemModel = try await itemRepository.find(id: item.$item.id, on: context.db) else {
                throw DomainError.notFound("Item not found.")
            }
            itemModel.$responsibleUser.id = targetUserID
            try await itemRepository.save(itemModel, on: context.db)
        }

        item.status = .approved
        item.approvedByUserID = approverID
        item.requestedToUserID = nil
        item.grabbedAt = Date()
        try await userItemRepository.save(item, on: context.db)

        let itemModel = try await requireItem(itemID: item.$item.id, on: context.db)
        let itemLabel = ItemJournalMessageFactory.itemLabel(name: itemModel.name, number: itemModel.number)
        let message: String
        let eventType: String
        if statusBeforeApprove == .transferRequested {
            let sourceOwner = try await userDisplayName(userID: sourceOwnerUserID, db: context.db)
            let targetOwner = try await userDisplayName(userID: transferTargetUserID, db: context.db)
            message = ItemJournalMessageFactory.transferApproved(
                approver: user.fullName,
                itemLabel: itemLabel,
                sourceOwner: sourceOwner,
                targetOwner: targetOwner
            )
            eventType = ItemJournalEventType.transferApproved
        } else {
            let requester = try await userDisplayName(userID: item.$user.id, db: context.db)
            message = ItemJournalMessageFactory.grabRequestApproved(
                approver: user.fullName,
                requester: requester,
                itemLabel: itemLabel
            )
            eventType = ItemJournalEventType.grabRequestApproved
        }
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: item.$item.id,
                actorUserID: user.id,
                eventType: eventType,
                message: message
            ),
            context: context
        )
        return item
    }

    func update(data: UserItemUpdateData, context: ServiceContext) async throws -> UserItem {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let item = try await userItemRepository.find(id: data.userItemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if !user.canApproveGrabRequests && item.$user.id != userID {
            throw DomainError.forbidden("You can only update your own request.")
        }

        try await userItemRepository.save(item, on: context.db)
        return item
    }

    func delete(data: UserItemDeleteData, context: ServiceContext) async throws {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let item = try await userItemRepository.find(id: data.userItemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if !user.canApproveGrabRequests && item.$user.id != userID {
            throw DomainError.forbidden("You can only delete your own request.")
        }

        try await userItemRepository.delete(item, on: context.db)
    }

    func `return`(data: UserItemReturnData, context: ServiceContext) async throws -> UUID? {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let itemModel = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        guard let grabbed = try await userItemRepository.findByItemID(itemID: data.itemID, on: context.db) else {
            throw DomainError.notFound("Item is not grabbed.")
        }

        if !user.canApproveGrabRequests && grabbed.$user.id != userID {
            throw DomainError.conflict("Item is grabbed by another user.")
        }

        let entityID = grabbed.id
        try await userItemRepository.delete(grabbed, on: context.db)

        let itemLabel = ItemJournalMessageFactory.itemLabel(name: itemModel.name, number: itemModel.number)
        let message = ItemJournalMessageFactory.itemReturned(actor: user.fullName, itemLabel: itemLabel)
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: data.itemID,
                actorUserID: user.id,
                eventType: ItemJournalEventType.itemReturned,
                message: message
            ),
            context: context
        )
        return entityID
    }

    func transferRequest(data: UserItemTransferData, context: ServiceContext) async throws -> UserItem {
        let user = try requireCurrentUser(context)
        guard user.canManageInventory else {
            throw DomainError.forbidden("This action requires materially responsible person, accountant, or admin role.")
        }

        let userID = try user.requireID()
        let targetUser = try await requireMateriallyResponsibleUser(data.toUserID, on: context.db)

        guard let grabbed = try await userItemRepository.findByItemID(itemID: data.itemID, on: context.db) else {
            throw DomainError.notFound("Item is not assigned.")
        }

        guard grabbed.$user.id == userID || user.canBypassRequestFlow else {
            throw DomainError.forbidden("Only current owner, accountant, or admin can request transfer.")
        }

        guard let targetUserID = try? targetUser.requireID(), grabbed.$user.id != targetUserID else {
            throw DomainError.badRequest("Item is already assigned to this user.")
        }

        grabbed.status = .transferRequested
        grabbed.approvedByUserID = nil
        grabbed.requestedToUserID = try targetUser.requireID()
        try await userItemRepository.save(grabbed, on: context.db)

        let itemModel = try await requireItem(itemID: data.itemID, on: context.db)
        let targetName = try await userDisplayName(userID: targetUser.id, db: context.db)
        let message = ItemJournalMessageFactory.transferRequested(
            actor: user.fullName,
            itemLabel: ItemJournalMessageFactory.itemLabel(name: itemModel.name, number: itemModel.number),
            target: targetName
        )
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: data.itemID,
                actorUserID: user.id,
                eventType: ItemJournalEventType.transferRequested,
                message: message
            ),
            context: context
        )
        return grabbed
    }

    func transfer(data: UserItemTransferData, context: ServiceContext) async throws -> UserItem {
        let user = try requireCurrentUser(context)
        guard user.canBypassRequestFlow else {
            throw DomainError.forbidden("Direct transfer is available only for accountant or admin.")
        }

        _ = try await requireMateriallyResponsibleUser(data.toUserID, on: context.db)

        guard let grabbed = try await userItemRepository.findByItemID(itemID: data.itemID, on: context.db) else {
            throw DomainError.notFound("Item is not assigned.")
        }

        guard grabbed.$user.id != data.toUserID else {
            throw DomainError.badRequest("Item is already assigned to this user.")
        }

        grabbed.$user.id = data.toUserID
        grabbed.status = .approved
        grabbed.approvedByUserID = try user.requireID()
        grabbed.requestedToUserID = nil
        grabbed.grabbedAt = Date()
        try await userItemRepository.save(grabbed, on: context.db)

        if let itemModel = try await itemRepository.find(id: data.itemID, on: context.db) {
            itemModel.$responsibleUser.id = data.toUserID
            try await itemRepository.save(itemModel, on: context.db)
        }

        let itemModel = try await requireItem(itemID: data.itemID, on: context.db)
        let targetName = try await userDisplayName(userID: data.toUserID, db: context.db)
        let message = ItemJournalMessageFactory.transferDirect(
            actor: user.fullName,
            itemLabel: ItemJournalMessageFactory.itemLabel(name: itemModel.name, number: itemModel.number),
            target: targetName
        )
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: data.itemID,
                actorUserID: user.id,
                eventType: ItemJournalEventType.transferDirect,
                message: message
            ),
            context: context
        )

        return grabbed
    }
}

extension DefaultUserItemService {
    private func requireCurrentUser(_ context: ServiceContext) throws -> User {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        return user
    }

    private func requireMateriallyResponsibleUser(_ userID: UUID, on db: Database) async throws -> User {
        guard let user = try await userRepository.find(id: userID, on: db) else {
            throw DomainError.notFound("Target user not found.")
        }
        guard user.role == .materiallyResponsiblePerson else {
            throw DomainError.badRequest("Target user must be materially_responsible_person.")
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

        _ = try await requireMateriallyResponsibleUser(resolvedTargetID, on: db)
        return resolvedTargetID
    }

    private func requireItem(itemID: UUID, on db: Database) async throws -> Item {
        guard let item = try await itemRepository.find(id: itemID, on: db) else {
            throw DomainError.notFound("Item not found.")
        }
        return item
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
}
