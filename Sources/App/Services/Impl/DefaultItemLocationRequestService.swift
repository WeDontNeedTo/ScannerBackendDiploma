import Fluent
import Fluent
import Foundation

struct DefaultItemLocationRequestService: ItemLocationRequestService {
    private let itemRepository: any ItemRepository
    private let locationRepository: any LocationRepository
    private let userRepository: any UserRepository
    private let itemLocationRepository: any ItemLocationRepository
    private let itemLocationRequestRepository: any ItemLocationRequestRepository
    private let itemJournalService: any ItemJournalService

    init(repositories: RepositoryContainer, itemJournalService: any ItemJournalService) {
        self.itemRepository = repositories.itemRepository
        self.locationRepository = repositories.locationRepository
        self.userRepository = repositories.userRepository
        self.itemLocationRepository = repositories.itemLocationRepository
        self.itemLocationRequestRepository = repositories.itemLocationRequestRepository
        self.itemJournalService = itemJournalService
    }

    func create(data: ItemLocationRequestCreateData, context: ServiceContext) async throws -> ItemLocationRequest {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let item = try await itemRepository.find(id: data.itemID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        guard let location = try await locationRepository.find(id: data.locationID, on: context.db) else {
            throw DomainError.notFound("Location not found.")
        }

        guard !canSetLocationDirectly(user: user, item: item) else {
            throw DomainError.conflict("You can change item location directly.")
        }

        guard let requestedToUserID = data.requestedToUserID else {
            throw DomainError.badRequest("requestedToUserID is required for location request flow.")
        }
        guard let targetUser = try await userRepository.find(id: requestedToUserID, on: context.db) else {
            throw DomainError.notFound("Requested approver not found.")
        }
        let isItemResponsibleApprover =
            targetUser.role == .materiallyResponsiblePerson
            && requestedToUserID == item.$responsibleUser.id
        guard targetUser.canBypassRequestFlow || isItemResponsibleApprover else {
            throw DomainError.badRequest(
                "Requested approver must be accountant/admin or current materially responsible user of item."
            )
        }

        if let existing = try await itemLocationRequestRepository.findRequested(
            itemID: data.itemID,
            locationID: data.locationID,
            requesterUserID: userID,
            on: context.db
        ) {
            return existing
        }

        let request = ItemLocationRequest(
            itemID: data.itemID,
            locationID: data.locationID,
            requesterUserID: userID,
            requestedToUserID: requestedToUserID
        )
        try await itemLocationRequestRepository.save(request, on: context.db)

        let itemLabel = ItemJournalMessageFactory.itemLabel(name: item.name, number: item.number)
        let message = ItemJournalMessageFactory.locationRequestCreated(
            actor: user.fullName,
            itemLabel: itemLabel,
            locationName: locationName(location),
            target: targetUser.fullName
        )
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: data.itemID,
                actorUserID: userID,
                eventType: ItemJournalEventType.locationRequestCreated,
                message: message
            ),
            context: context
        )
        return request
    }

    func incoming(context: ServiceContext) async throws -> [ItemLocationRequest] {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()
        guard user.canBypassRequestFlow || user.role == .materiallyResponsiblePerson else {
            return []
        }
        return try await itemLocationRequestRepository.listIncoming(for: userID, on: context.db)
    }

    func approve(data: ItemLocationRequestApproveData, context: ServiceContext) async throws -> ItemLocationRequest {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let request = try await itemLocationRequestRepository.find(id: data.requestID, on: context.db) else {
            throw DomainError.notFound("Location request not found.")
        }
        guard request.status == .requested else {
            throw DomainError.conflict("Location request is already processed.")
        }
        guard let item = try await itemRepository.find(id: request.$item.id, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        guard canApproveLocationRequest(user: user, item: item, userID: userID) else {
            throw DomainError.forbidden(
                "Only accountant, admin, or current materially responsible user can approve location requests."
            )
        }
        if let requestedToUserID = request.requestedToUserID,
            requestedToUserID != userID,
            user.role != .admin
        {
            throw DomainError.forbidden("Location request assigned to another approver.")
        }
        guard let location = try await locationRepository.find(id: request.$location.id, on: context.db) else {
            throw DomainError.notFound("Location not found.")
        }

        if let existing = try await itemLocationRepository.find(
            itemID: request.$item.id,
            locationID: request.$location.id,
            on: context.db
        ) {
            try await itemLocationRepository.save(existing, on: context.db)
        } else {
            let itemLocation = ItemLocation(itemID: request.$item.id, locationID: request.$location.id)
            try await itemLocationRepository.save(itemLocation, on: context.db)
        }

        request.status = .approved
        request.approvedByUserID = userID
        try await itemLocationRequestRepository.save(request, on: context.db)

        let requesterName = try await userDisplayName(userID: request.$requester.id, db: context.db)
        let message = ItemJournalMessageFactory.locationRequestApproved(
            approver: user.fullName,
            requester: requesterName,
            itemLabel: ItemJournalMessageFactory.itemLabel(name: item.name, number: item.number),
            locationName: locationName(location)
        )
        try await itemJournalService.record(
            data: ItemJournalRecordData(
                itemID: request.$item.id,
                actorUserID: userID,
                eventType: ItemJournalEventType.locationRequestApproved,
                message: message
            ),
            context: context
        )
        return request
    }
}

extension DefaultItemLocationRequestService {
    private func requireCurrentUser(_ context: ServiceContext) throws -> User {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        return user
    }

    private func canSetLocationDirectly(user: User, item: Item) -> Bool {
        if user.canBypassRequestFlow {
            return true
        }
        return item.$responsibleUser.id == user.id
    }

    private func canApproveLocationRequest(user: User, item: Item, userID: UUID) -> Bool {
        if user.canBypassRequestFlow {
            return true
        }
        return user.role == .materiallyResponsiblePerson && item.$responsibleUser.id == userID
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

    private func locationName(_ location: Location) -> String {
        if location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ItemJournalMessageFactory.unknownLocation()
        }
        return location.name
    }
}
