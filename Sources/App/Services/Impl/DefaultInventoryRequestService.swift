import Fluent
import Foundation

struct DefaultInventoryRequestService: InventoryRequestService {
    private let inventoryRequestRepository: any InventoryRequestRepository
    private let inventoryRequestItemRepository: any InventoryRequestItemRepository
    private let userRepository: any UserRepository
    private let itemRepository: any ItemRepository

    init(repositories: RepositoryContainer) {
        self.inventoryRequestRepository = repositories.inventoryRequestRepository
        self.inventoryRequestItemRepository = repositories.inventoryRequestItemRepository
        self.userRepository = repositories.userRepository
        self.itemRepository = repositories.itemRepository
    }

    func createDraft(data: InventoryRequestCreateDraftData, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()
        try requireAccountantOrAdmin(user)

        guard let mrp = try await userRepository.find(id: data.materiallyResponsibleUserID, on: context.db) else {
            throw DomainError.notFound("Materially responsible user not found.")
        }
        guard mrp.role == .materiallyResponsiblePerson else {
            throw DomainError.badRequest("Selected user must be materially_responsible_person.")
        }

        let inventoryDate = try parseInventoryDate(data.inventoryDate)
        let request = InventoryRequest(
            requesterUserID: userID,
            materiallyResponsibleUserID: data.materiallyResponsibleUserID,
            inventoryDate: inventoryDate
        )
        try await inventoryRequestRepository.create(request, on: context.db)

        return try await buildResponse(requestID: try request.requireID(), on: context.db)
    }

    func setItems(data: InventoryRequestSetItemsData, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let request = try await inventoryRequestRepository.find(id: data.requestID, on: context.db) else {
            throw DomainError.notFound("Inventory request not found.")
        }

        try requireRequestCreator(userID: userID, request: request)
        try requireAccountantOrAdmin(user)

        guard request.status == .draft else {
            throw DomainError.conflict("Only draft inventory request can be edited.")
        }

        let uniqueItemIDs = normalizeUniqueItemIDs(data.itemIDs)

        if !uniqueItemIDs.isEmpty {
            let conflictingItemIDs = try await inventoryRequestRepository.findActiveConflictingItemIDs(
                itemIDs: uniqueItemIDs,
                excludingRequestID: data.requestID,
                on: context.db
            )
            if !conflictingItemIDs.isEmpty {
                let sortedIDs = conflictingItemIDs.map(\.uuidString).sorted().joined(separator: ",")
                throw DomainError.conflict("Some selected items already participate in active inventory requests: \(sortedIDs)")
            }
        }

        var itemsToCreate: [InventoryRequestItem] = []
        itemsToCreate.reserveCapacity(uniqueItemIDs.count)
        for itemID in uniqueItemIDs {
            guard let item = try await itemRepository.find(id: itemID, on: context.db) else {
                throw DomainError.notFound("Item not found.")
            }
            guard item.$responsibleUser.id == request.$materiallyResponsibleUser.id else {
                throw DomainError.badRequest("All selected items must belong to selected materially responsible user.")
            }
            itemsToCreate.append(
                InventoryRequestItem(
                    requestID: data.requestID,
                    itemID: itemID,
                    itemNumberSnapshot: item.number,
                    itemNameSnapshot: item.name,
                    status: .pending
                )
            )
        }

        let replacementItems = itemsToCreate
        try await context.db.transaction { db in
            try await inventoryRequestItemRepository.deleteByRequestID(requestID: data.requestID, on: db)
            for requestItem in replacementItems {
                try await inventoryRequestItemRepository.create(requestItem, on: db)
            }
        }

        return try await buildResponse(requestID: data.requestID, on: context.db)
    }

    func submit(data: InventoryRequestSubmitData, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let request = try await inventoryRequestRepository.find(id: data.requestID, on: context.db) else {
            throw DomainError.notFound("Inventory request not found.")
        }
        try requireRequestCreator(userID: userID, request: request)
        try requireAccountantOrAdmin(user)

        guard request.status == .draft else {
            throw DomainError.conflict("Only draft inventory request can be submitted.")
        }

        let items = try await inventoryRequestItemRepository.listByRequestID(requestID: data.requestID, on: context.db)
        guard !items.isEmpty else {
            throw DomainError.badRequest("Select at least one item before submit.")
        }

        request.status = .submitted
        request.submittedAt = Date()
        try await inventoryRequestRepository.save(request, on: context.db)

        return try await buildResponse(requestID: data.requestID, on: context.db)
    }

    func incoming(context: ServiceContext) async throws -> [InventoryRequestResponse] {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard user.role == .materiallyResponsiblePerson else {
            throw DomainError.forbidden("Only materially responsible person can view incoming inventory requests.")
        }

        let requests = try await inventoryRequestRepository.listIncoming(
            materiallyResponsibleUserID: userID,
            on: context.db
        )
        return try await mapRequests(requests, on: context.db)
    }

    func mine(context: ServiceContext) async throws -> [InventoryRequestResponse] {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        try requireAccountantOrAdmin(user)

        let requests = try await inventoryRequestRepository.listMine(requesterUserID: userID, on: context.db)
        return try await mapRequests(requests, on: context.db)
    }

    func show(requestID: UUID, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()
        let (request, _) = try await requireRequestWithAccess(requestID: requestID, userID: userID, on: context.db)

        return try await buildResponse(requestID: try request.requireID(), on: context.db)
    }

    func scanItem(data: InventoryRequestScanData, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()
        let (request, _) = try await requireRequestWithAccess(requestID: data.requestID, userID: userID, on: context.db)

        guard request.$materiallyResponsibleUser.id == userID else {
            throw DomainError.forbidden("Only assigned materially responsible user can scan inventory items.")
        }
        guard request.status == .submitted else {
            throw DomainError.conflict("Inventory request is not in submitted status.")
        }
        guard data.scannedItemID == data.itemID else {
            throw DomainError.conflict("Scanned item does not match expected inventory item.")
        }

        guard let requestItem = try await inventoryRequestItemRepository.find(
            requestID: data.requestID,
            itemID: data.itemID,
            on: context.db
        ) else {
            throw DomainError.notFound("Inventory request item not found.")
        }

        requestItem.status = .found
        requestItem.scannedAt = Date()
        requestItem.scannedByUserID = userID
        requestItem.scannedItemID = data.scannedItemID
        try await inventoryRequestItemRepository.save(requestItem, on: context.db)

        return try await buildResponse(requestID: data.requestID, on: context.db)
    }

    func mrpComplete(data: InventoryRequestMRPCompleteData, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()
        let (request, items) = try await requireRequestWithAccess(requestID: data.requestID, userID: userID, on: context.db)

        guard request.$materiallyResponsibleUser.id == userID else {
            throw DomainError.forbidden("Only assigned materially responsible user can complete inventory request.")
        }
        guard request.status == .submitted else {
            throw DomainError.conflict("Inventory request is not in submitted status.")
        }

        switch data.outcome {
        case .success:
            if items.contains(where: { $0.status != .found }) {
                throw DomainError.conflict("All items must be found to complete inventory with success outcome.")
            }
            request.status = .mrpCompletedSuccess

        case .missing:
            for item in items where item.status == .pending {
                item.status = .missing
                try await inventoryRequestItemRepository.save(item, on: context.db)
            }
            request.status = .mrpCompletedMissing
        }

        request.mrpCompletedAt = Date()
        request.mrpCompletedByUserID = userID
        try await inventoryRequestRepository.save(request, on: context.db)

        return try await buildResponse(requestID: data.requestID, on: context.db)
    }

    func finalApprove(data: InventoryRequestFinalApproveData, context: ServiceContext) async throws -> InventoryRequestResponse {
        let user = try requireCurrentUser(context)
        let userID = try user.requireID()

        guard let request = try await inventoryRequestRepository.find(id: data.requestID, on: context.db) else {
            throw DomainError.notFound("Inventory request not found.")
        }

        try requireRequestCreator(userID: userID, request: request)
        try requireAccountantOrAdmin(user)

        switch request.status {
        case .mrpCompletedSuccess:
            request.status = .finalizedSuccess
        case .mrpCompletedMissing:
            request.status = .finalizedMissing
        default:
            throw DomainError.conflict("Inventory request must be completed by materially responsible user before final approval.")
        }

        request.finalApprovedAt = Date()
        request.finalApprovedByUserID = userID
        try await inventoryRequestRepository.save(request, on: context.db)

        return try await buildResponse(requestID: data.requestID, on: context.db)
    }
}

extension DefaultInventoryRequestService {
    private func requireCurrentUser(_ context: ServiceContext) throws -> User {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        return user
    }

    private func requireAccountantOrAdmin(_ user: User) throws {
        guard user.role == .accountant || user.role == .admin else {
            throw DomainError.forbidden("This action requires accountant or admin role.")
        }
    }

    private func requireRequestCreator(userID: UUID, request: InventoryRequest) throws {
        guard request.$requester.id == userID else {
            throw DomainError.forbidden("Only creator of inventory request can perform this action.")
        }
    }

    private func parseInventoryDate(_ rawDate: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = formatter.date(from: rawDate) else {
            throw DomainError.badRequest("inventoryDate must be in YYYY-MM-DD format.")
        }
        return date
    }

    private func formatInventoryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func normalizeUniqueItemIDs(_ itemIDs: [UUID]) -> [UUID] {
        Array(Set(itemIDs)).sorted(by: { $0.uuidString < $1.uuidString })
    }

    private func requireRequestWithAccess(
        requestID: UUID,
        userID: UUID,
        on db: Database
    ) async throws -> (InventoryRequest, [InventoryRequestItem]) {
        guard let request = try await inventoryRequestRepository.find(id: requestID, on: db) else {
            throw DomainError.notFound("Inventory request not found.")
        }

        let canAccess = request.$requester.id == userID || request.$materiallyResponsibleUser.id == userID
        guard canAccess else {
            throw DomainError.forbidden("You do not have access to this inventory request.")
        }

        let items = try await inventoryRequestItemRepository.listByRequestID(requestID: requestID, on: db)
        return (request, items)
    }

    private func mapRequests(_ requests: [InventoryRequest], on db: Database) async throws -> [InventoryRequestResponse] {
        var responses: [InventoryRequestResponse] = []
        responses.reserveCapacity(requests.count)

        for request in requests {
            let requestID = try request.requireID()
            responses.append(try await buildResponse(requestID: requestID, on: db))
        }

        return responses
    }

    private func buildResponse(requestID: UUID, on db: Database) async throws -> InventoryRequestResponse {
        guard let request = try await inventoryRequestRepository.find(id: requestID, on: db) else {
            throw DomainError.notFound("Inventory request not found.")
        }

        let items = try await inventoryRequestItemRepository.listByRequestID(requestID: requestID, on: db)
            .sorted { lhs, rhs in
                if lhs.itemNumberSnapshot != rhs.itemNumberSnapshot {
                    return lhs.itemNumberSnapshot < rhs.itemNumberSnapshot
                }
                return (lhs.id?.uuidString ?? "") < (rhs.id?.uuidString ?? "")
            }

        return InventoryRequestResponse(
            id: request.id,
            requesterUserID: request.$requester.id,
            materiallyResponsibleUserID: request.$materiallyResponsibleUser.id,
            inventoryDate: formatInventoryDate(request.inventoryDate),
            status: request.status,
            submittedAt: request.submittedAt,
            mrpCompletedAt: request.mrpCompletedAt,
            mrpCompletedByUserID: request.mrpCompletedByUserID,
            finalApprovedAt: request.finalApprovedAt,
            finalApprovedByUserID: request.finalApprovedByUserID,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt,
            items: items.map { item in
                InventoryRequestItemResponse(
                    id: item.id,
                    itemID: item.$item.id,
                    itemNumber: item.itemNumberSnapshot,
                    itemName: item.itemNameSnapshot,
                    status: item.status,
                    scannedAt: item.scannedAt,
                    scannedByUserID: item.scannedByUserID,
                    scannedItemID: item.scannedItemID
                )
            }
        )
    }
}
