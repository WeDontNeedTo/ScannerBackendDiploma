import Fluent
@testable import App
import XCTVapor

final class InventoryRequestServiceTests: XCTestCase {
    func testCreateDraftByAccountantSucceeds() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let accountant = makeInventoryUser(role: .accountant)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)

        let userRepository = InventoryTestUserRepository()
        userRepository.findHandler = { _, id in
            id == mrp.id ? mrp : nil
        }

        let requestRepository = InventoryTestInventoryRequestRepository()

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: userRepository,
                requestRepository: requestRepository,
                requestItemRepository: InventoryTestInventoryRequestItemRepository(),
                itemRepository: InventoryTestItemRepository()
            )
        )

        let response = try await service.createDraft(
            data: InventoryRequestCreateDraftData(
                materiallyResponsibleUserID: try mrp.requireID(),
                inventoryDate: "2026-03-10"
            ),
            context: ServiceContext(db: app.db, currentUser: accountant)
        )

        XCTAssertEqual(response.status, .draft)
        XCTAssertEqual(response.materiallyResponsibleUserID, try mrp.requireID())
        XCTAssertEqual(response.requesterUserID, try accountant.requireID())
        XCTAssertEqual(response.inventoryDate, "2026-03-10")
    }

    func testCreateDraftByEmployeeIsForbidden() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let employee = makeInventoryUser(role: .employee)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)

        let userRepository = InventoryTestUserRepository()
        userRepository.findHandler = { _, id in
            id == mrp.id ? mrp : nil
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: userRepository,
                requestRepository: InventoryTestInventoryRequestRepository(),
                requestItemRepository: InventoryTestInventoryRequestItemRepository(),
                itemRepository: InventoryTestItemRepository()
            )
        )

        do {
            _ = try await service.createDraft(
                data: InventoryRequestCreateDraftData(
                    materiallyResponsibleUserID: try mrp.requireID(),
                    inventoryDate: "2026-03-10"
                ),
                context: ServiceContext(db: app.db, currentUser: employee)
            )
            XCTFail("Expected forbidden")
        } catch let error as DomainError {
            guard case .forbidden = error else {
                XCTFail("Expected forbidden")
                return
            }
        }
    }

    func testSetItemsRejectsItemsFromAnotherResponsibleUser() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let accountant = makeInventoryUser(role: .accountant)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let anotherMRP = makeInventoryUser(role: .materiallyResponsiblePerson)
        let item = makeInventoryItem(responsibleUserID: try anotherMRP.requireID())

        let request = makeInventoryRequest(
            requesterUserID: try accountant.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .draft
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }

        let itemRepository = InventoryTestItemRepository()
        itemRepository.findHandler = { _, id in
            id == item.id ? item : nil
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: InventoryTestInventoryRequestItemRepository(),
                itemRepository: itemRepository
            )
        )

        do {
            _ = try await service.setItems(
                data: InventoryRequestSetItemsData(requestID: try request.requireID(), itemIDs: [try item.requireID()]),
                context: ServiceContext(db: app.db, currentUser: accountant)
            )
            XCTFail("Expected badRequest")
        } catch let error as DomainError {
            guard case .badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }
    }

    func testSetItemsRejectsOverlap() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let accountant = makeInventoryUser(role: .accountant)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let item = makeInventoryItem(responsibleUserID: try mrp.requireID())

        let request = makeInventoryRequest(
            requesterUserID: try accountant.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .draft
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }
        requestRepository.findConflictsHandler = { _, _, _ in
            [try item.requireID()]
        }

        let itemRepository = InventoryTestItemRepository()
        itemRepository.findHandler = { _, id in
            id == item.id ? item : nil
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: InventoryTestInventoryRequestItemRepository(),
                itemRepository: itemRepository
            )
        )

        do {
            _ = try await service.setItems(
                data: InventoryRequestSetItemsData(requestID: try request.requireID(), itemIDs: [try item.requireID()]),
                context: ServiceContext(db: app.db, currentUser: accountant)
            )
            XCTFail("Expected conflict")
        } catch let error as DomainError {
            guard case .conflict = error else {
                XCTFail("Expected conflict")
                return
            }
        }
    }

    func testSubmitFailsWhenNoItemsSelected() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let accountant = makeInventoryUser(role: .accountant)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let request = makeInventoryRequest(
            requesterUserID: try accountant.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .draft
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.listByRequestIDHandler = { _, _ in [] }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        do {
            _ = try await service.submit(
                data: InventoryRequestSubmitData(requestID: try request.requireID()),
                context: ServiceContext(db: app.db, currentUser: accountant)
            )
            XCTFail("Expected badRequest")
        } catch let error as DomainError {
            guard case .badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }
    }

    func testIncomingForMRPReturnsSubmittedRequests() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let requester = makeInventoryUser(role: .accountant)

        let request = makeInventoryRequest(
            requesterUserID: try requester.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .submitted
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.listIncomingHandler = { _, _ in [request] }
        requestRepository.findHandler = { _, id in
            id == request.id ? request : nil
        }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.listByRequestIDHandler = { _, _ in [] }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        let responses = try await service.incoming(context: ServiceContext(db: app.db, currentUser: mrp))

        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses[0].status, .submitted)
    }

    func testScanMarksItemAsFoundWhenUUIDMatches() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let requester = makeInventoryUser(role: .accountant)
        let item = makeInventoryItem(responsibleUserID: try mrp.requireID())
        let request = makeInventoryRequest(
            requesterUserID: try requester.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .submitted
        )

        var requestItem = makeInventoryRequestItem(requestID: try request.requireID(), itemID: try item.requireID())

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.findByRequestItemHandler = { _, _, _ in requestItem }
        requestItemRepository.listByRequestIDHandler = { _, _ in [requestItem] }
        requestItemRepository.saveHandler = { _, value in
            requestItem = value
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        _ = try await service.scanItem(
            data: InventoryRequestScanData(
                requestID: try request.requireID(),
                itemID: try item.requireID(),
                scannedItemID: try item.requireID()
            ),
            context: ServiceContext(db: app.db, currentUser: mrp)
        )

        XCTAssertEqual(requestItem.status, .found)
        XCTAssertEqual(requestItem.scannedByUserID, try mrp.requireID())
        XCTAssertEqual(requestItem.scannedItemID, try item.requireID())
        XCTAssertNotNil(requestItem.scannedAt)
    }

    func testScanFailsWhenUUIDDoesNotMatchExpectedItem() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let requester = makeInventoryUser(role: .accountant)
        let item = makeInventoryItem(responsibleUserID: try mrp.requireID())
        let request = makeInventoryRequest(
            requesterUserID: try requester.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .submitted
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.findByRequestItemHandler = { _, _, _ in
            makeInventoryRequestItem(requestID: try request.requireID(), itemID: try item.requireID())
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        do {
            _ = try await service.scanItem(
                data: InventoryRequestScanData(
                    requestID: try request.requireID(),
                    itemID: try item.requireID(),
                    scannedItemID: UUID()
                ),
                context: ServiceContext(db: app.db, currentUser: mrp)
            )
            XCTFail("Expected conflict")
        } catch let error as DomainError {
            guard case .conflict = error else {
                XCTFail("Expected conflict")
                return
            }
        }
    }

    func testMRPCompleteSuccessFailsIfAnyItemNotFound() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let requester = makeInventoryUser(role: .accountant)
        let item = makeInventoryItem(responsibleUserID: try mrp.requireID())
        let request = makeInventoryRequest(
            requesterUserID: try requester.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .submitted
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.listByRequestIDHandler = { _, _ in
            [makeInventoryRequestItem(requestID: try request.requireID(), itemID: try item.requireID(), status: .pending)]
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        do {
            _ = try await service.mrpComplete(
                data: InventoryRequestMRPCompleteData(
                    requestID: try request.requireID(),
                    outcome: .success
                ),
                context: ServiceContext(db: app.db, currentUser: mrp)
            )
            XCTFail("Expected conflict")
        } catch let error as DomainError {
            guard case .conflict = error else {
                XCTFail("Expected conflict")
                return
            }
        }
    }

    func testMRPCompleteMissingMarksPendingItemsAsMissing() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let requester = makeInventoryUser(role: .accountant)
        let itemA = makeInventoryItem(responsibleUserID: try mrp.requireID())
        let itemB = makeInventoryItem(responsibleUserID: try mrp.requireID())
        let request = makeInventoryRequest(
            requesterUserID: try requester.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .submitted
        )

        var pending = makeInventoryRequestItem(requestID: try request.requireID(), itemID: try itemA.requireID(), status: .pending)
        var found = makeInventoryRequestItem(requestID: try request.requireID(), itemID: try itemB.requireID(), status: .found)
        var savedRequest: InventoryRequest?

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }
        requestRepository.saveHandler = { _, value in savedRequest = value }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.listByRequestIDHandler = { _, _ in [pending, found] }
        requestItemRepository.saveHandler = { _, value in
            if value.$item.id == pending.$item.id {
                pending = value
            }
            if value.$item.id == found.$item.id {
                found = value
            }
        }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        _ = try await service.mrpComplete(
            data: InventoryRequestMRPCompleteData(
                requestID: try request.requireID(),
                outcome: .missing
            ),
            context: ServiceContext(db: app.db, currentUser: mrp)
        )

        XCTAssertEqual(pending.status, .missing)
        XCTAssertEqual(found.status, .found)
        XCTAssertEqual(savedRequest?.status, .mrpCompletedMissing)
        XCTAssertEqual(savedRequest?.mrpCompletedByUserID, try mrp.requireID())
        XCTAssertNotNil(savedRequest?.mrpCompletedAt)
    }

    func testFinalApproveOnlyCreatorCanApprove() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let creator = makeInventoryUser(role: .accountant)
        let anotherAccountant = makeInventoryUser(role: .accountant)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)
        let request = makeInventoryRequest(
            requesterUserID: try creator.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .mrpCompletedSuccess
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, _ in request }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: InventoryTestInventoryRequestItemRepository(),
                itemRepository: InventoryTestItemRepository()
            )
        )

        do {
            _ = try await service.finalApprove(
                data: InventoryRequestFinalApproveData(requestID: try request.requireID()),
                context: ServiceContext(db: app.db, currentUser: anotherAccountant)
            )
            XCTFail("Expected forbidden")
        } catch let error as DomainError {
            guard case .forbidden = error else {
                XCTFail("Expected forbidden")
                return
            }
        }
    }

    func testFinalApproveSetsFinalStatuses() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let creator = makeInventoryUser(role: .accountant)
        let mrp = makeInventoryUser(role: .materiallyResponsiblePerson)

        var successRequest = makeInventoryRequest(
            requesterUserID: try creator.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .mrpCompletedSuccess
        )
        var missingRequest = makeInventoryRequest(
            requesterUserID: try creator.requireID(),
            materiallyResponsibleUserID: try mrp.requireID(),
            status: .mrpCompletedMissing
        )

        let requestRepository = InventoryTestInventoryRequestRepository()
        requestRepository.findHandler = { _, id in
            if id == successRequest.id {
                return successRequest
            }
            if id == missingRequest.id {
                return missingRequest
            }
            return nil
        }
        requestRepository.saveHandler = { _, value in
            if value.id == successRequest.id {
                successRequest = value
            }
            if value.id == missingRequest.id {
                missingRequest = value
            }
        }

        let requestItemRepository = InventoryTestInventoryRequestItemRepository()
        requestItemRepository.listByRequestIDHandler = { _, _ in [] }

        let service = DefaultInventoryRequestService(
            repositories: makeInventoryRepositoryContainer(
                userRepository: InventoryTestUserRepository(),
                requestRepository: requestRepository,
                requestItemRepository: requestItemRepository,
                itemRepository: InventoryTestItemRepository()
            )
        )

        _ = try await service.finalApprove(
            data: InventoryRequestFinalApproveData(requestID: try successRequest.requireID()),
            context: ServiceContext(db: app.db, currentUser: creator)
        )

        _ = try await service.finalApprove(
            data: InventoryRequestFinalApproveData(requestID: try missingRequest.requireID()),
            context: ServiceContext(db: app.db, currentUser: creator)
        )

        XCTAssertEqual(successRequest.status, .finalizedSuccess)
        XCTAssertEqual(missingRequest.status, .finalizedMissing)
        XCTAssertEqual(successRequest.finalApprovedByUserID, try creator.requireID())
        XCTAssertEqual(missingRequest.finalApprovedByUserID, try creator.requireID())
        XCTAssertNotNil(successRequest.finalApprovedAt)
        XCTAssertNotNil(missingRequest.finalApprovedAt)
    }
}

private func makeInventoryRepositoryContainer(
    userRepository: any UserRepository,
    requestRepository: any InventoryRequestRepository,
    requestItemRepository: any InventoryRequestItemRepository,
    itemRepository: any ItemRepository
) -> RepositoryContainer {
    RepositoryContainer(
        itemRepository: itemRepository,
        userRepository: userRepository,
        userItemRepository: InventoryTestUserItemRepository(),
        itemLocationRepository: InventoryTestItemLocationRepository(),
        itemLocationRequestRepository: InventoryTestItemLocationRequestRepository(),
        inventoryRequestRepository: requestRepository,
        inventoryRequestItemRepository: requestItemRepository,
        itemJournalRepository: InventoryTestItemJournalRepository(),
        brokenItemRepository: InventoryTestBrokenItemRepository(),
        itemCategoryRepository: InventoryTestItemCategoryRepository(),
        locationRepository: InventoryTestLocationRepository(),
        itemParameterRepository: InventoryTestItemParameterRepository(),
        userTokenRepository: InventoryTestUserTokenRepository()
    )
}

private func makeInventoryUser(role: UserRole) -> User {
    let user = User(
        login: UUID().uuidString,
        passwordHash: "hash",
        fullName: "Inventory User",
        age: 30,
        position: "Engineer",
        role: role
    )
    user.id = UUID()
    return user
}

private func makeInventoryItem(responsibleUserID: UUID) -> Item {
    let item = Item(number: "INV-\(UUID().uuidString)", name: "Inventory Item", responsibleUserID: responsibleUserID)
    item.id = UUID()
    return item
}

private func makeInventoryRequest(
    requesterUserID: UUID,
    materiallyResponsibleUserID: UUID,
    status: InventoryRequestStatus
) -> InventoryRequest {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    let request = InventoryRequest(
        requesterUserID: requesterUserID,
        materiallyResponsibleUserID: materiallyResponsibleUserID,
        inventoryDate: formatter.date(from: "2026-03-10") ?? Date(),
        status: status
    )
    request.id = UUID()
    return request
}

private func makeInventoryRequestItem(
    requestID: UUID,
    itemID: UUID,
    status: InventoryRequestItemStatus = .pending
) -> InventoryRequestItem {
    let item = InventoryRequestItem(
        requestID: requestID,
        itemID: itemID,
        itemNumberSnapshot: "N-\(UUID().uuidString)",
        itemNameSnapshot: "Snapshot Item",
        status: status
    )
    item.id = UUID()
    return item
}

private final class InventoryTestItemRepository: ItemRepository {
    var findHandler: ((Database, UUID) throws -> Item?)?

    func listWithRelations(on db: Database) async throws -> [Item] { [] }
    func findWithRelations(id: UUID, on db: Database) async throws -> Item? { nil }
    func findWithRelations(number: String, on db: Database) async throws -> Item? { nil }
    func search(with data: ItemSearchData, on db: Database) async throws -> [Item] { [] }
    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats {
        DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero, items: [])
    }
    func countByResponsibleUser(responsibleUserID: UUID, on db: Database) async throws -> Int { 0 }
    func listByResponsibleUserWithRelations(responsibleUserID: UUID, on db: Database) async throws -> [Item] { [] }
    func findAllByIDs(_ ids: [UUID], on db: Database) async throws -> [Item] { [] }
    func findAllByIDsWithRelations(_ ids: [UUID], on db: Database) async throws -> [Item] { [] }
    func saveAll(_ items: [Item], on db: Database) async throws {}
    func find(id: UUID, on db: Database) async throws -> Item? {
        try findHandler?(db, id)
    }
    func save(_ item: Item, on db: Database) async throws {}
    func delete(_ item: Item, on db: Database) async throws {}
}

private final class InventoryTestUserRepository: UserRepository {
    var findHandler: ((Database, UUID) throws -> User?)?

    func find(id: UUID, on db: Database) async throws -> User? {
        try findHandler?(db, id)
    }
    func findByLogin(_ login: String, on db: Database) async throws -> User? { nil }
    func list(page: Int, per: Int, on db: Database) async throws -> [User] { [] }
    func count(on db: Database) async throws -> Int { 0 }
    func listMateriallyResponsible(on db: Database) async throws -> [User] { [] }
    func save(_ user: User, on db: Database) async throws {}
}

private final class InventoryTestInventoryRequestRepository: InventoryRequestRepository {
    var createdRequest: InventoryRequest?
    var findHandler: ((Database, UUID) throws -> InventoryRequest?)?
    var findWithItemsHandler: ((Database, UUID) throws -> InventoryRequest?)?
    var listIncomingHandler: ((Database, UUID) throws -> [InventoryRequest])?
    var listMineHandler: ((Database, UUID) throws -> [InventoryRequest])?
    var saveHandler: ((Database, InventoryRequest) throws -> Void)?
    var findConflictsHandler: ((Database, [UUID], UUID?) throws -> Set<UUID>)?

    func create(_ request: InventoryRequest, on db: Database) async throws {
        if request.id == nil {
            request.id = UUID()
        }
        createdRequest = request
    }

    func find(id: UUID, on db: Database) async throws -> InventoryRequest? {
        if let resolved = try findHandler?(db, id) {
            return resolved
        }
        if createdRequest?.id == id {
            return createdRequest
        }
        return nil
    }

    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest? {
        if let resolved = try findWithItemsHandler?(db, id) {
            return resolved
        }
        return try await find(id: id, on: db)
    }

    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest] {
        try listIncomingHandler?(db, materiallyResponsibleUserID) ?? []
    }

    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest] {
        try listMineHandler?(db, requesterUserID) ?? []
    }

    func save(_ request: InventoryRequest, on db: Database) async throws {
        try saveHandler?(db, request)
    }

    func findActiveConflictingItemIDs(
        itemIDs: [UUID],
        excludingRequestID: UUID?,
        on db: Database
    ) async throws -> Set<UUID> {
        try findConflictsHandler?(db, itemIDs, excludingRequestID) ?? []
    }
}

private final class InventoryTestInventoryRequestItemRepository: InventoryRequestItemRepository {
    var createHandler: ((Database, InventoryRequestItem) throws -> Void)?
    var findByRequestItemHandler: ((Database, UUID, UUID) throws -> InventoryRequestItem?)?
    var listByRequestIDHandler: ((Database, UUID) throws -> [InventoryRequestItem])?
    var deleteByRequestIDHandler: ((Database, UUID) throws -> Void)?
    var saveHandler: ((Database, InventoryRequestItem) throws -> Void)?

    func create(_ item: InventoryRequestItem, on db: Database) async throws {
        try createHandler?(db, item)
    }

    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem? {
        try findByRequestItemHandler?(db, requestID, itemID)
    }

    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem] {
        try listByRequestIDHandler?(db, requestID) ?? []
    }

    func deleteByRequestID(requestID: UUID, on db: Database) async throws {
        try deleteByRequestIDHandler?(db, requestID)
    }

    func save(_ item: InventoryRequestItem, on db: Database) async throws {
        try saveHandler?(db, item)
    }
}

private struct InventoryTestUserItemRepository: UserItemRepository {
    func listForUser(userID: UUID, on db: Database) async throws -> [UserItem] { [] }
    func listAllWithItem(on db: Database) async throws -> [UserItem] { [] }
    func listIncoming(for userID: UUID, on db: Database) async throws -> [UserItem] { [] }
    func find(id: UUID, on db: Database) async throws -> UserItem? { nil }
    func findWithItem(id: UUID, on db: Database) async throws -> UserItem? { nil }
    func findByItemID(itemID: UUID, on db: Database) async throws -> UserItem? { nil }
    func findByItemIDWithUser(itemID: UUID, on db: Database) async throws -> UserItem? { nil }
    func save(_ userItem: UserItem, on db: Database) async throws {}
    func delete(_ userItem: UserItem, on db: Database) async throws {}
}

private struct InventoryTestItemLocationRepository: ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? { nil }
    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] { [] }
    func save(_ itemLocation: ItemLocation, on db: Database) async throws {}
}

private struct InventoryTestItemLocationRequestRepository: ItemLocationRequestRepository {
    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest] { [] }
    func save(_ request: ItemLocationRequest, on db: Database) async throws {}
}

private struct InventoryTestItemJournalRepository: ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws {}
    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] { [] }
    func count(itemID: UUID, on db: Database) async throws -> Int { 0 }
}

private struct InventoryTestBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool { false }
    func listWithItem(on db: Database) async throws -> [BrokenItem] { [] }
    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem] { [] }
    func save(_ brokenItem: BrokenItem, on db: Database) async throws {}
}

private struct InventoryTestItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] { [] }
    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount] { [] }
    func exists(id: UUID, on db: Database) async throws -> Bool { false }
    func find(id: UUID, on db: Database) async throws -> ItemCategory? { nil }
    func save(_ category: ItemCategory, on db: Database) async throws {}
    func delete(_ category: ItemCategory, on db: Database) async throws {}
}

private struct InventoryTestLocationRepository: LocationRepository {
    func list(on db: Database) async throws -> [Location] { [] }
    func find(id: UUID, on db: Database) async throws -> Location? { nil }
    func save(_ location: Location, on db: Database) async throws {}
    func delete(_ location: Location, on db: Database) async throws {}
}

private struct InventoryTestItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] { [] }
    func find(id: UUID, on db: Database) async throws -> ItemParameter? { nil }
    func save(_ parameter: ItemParameter, on db: Database) async throws {}
    func delete(_ parameter: ItemParameter, on db: Database) async throws {}
}

private struct InventoryTestUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {}
    func deleteByUserID(_ userID: UUID, on db: Database) async throws {}
}
