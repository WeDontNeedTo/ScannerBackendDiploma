import Fluent
@testable import App
import XCTVapor

final class ItemLocationRequestServiceTests: XCTestCase {
    func testEmployeeCanCreateLocationRequestToAccountant() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let employee = makeLocationRequestUser(role: .employee)
        let accountant = makeLocationRequestUser(role: .accountant)
        let item = makeLocationRequestItem(responsibleUserID: UUID())
        let location = makeLocationRequestLocation()

        let itemRepository = LocationRequestItemRepository()
        itemRepository.findHandler = { _, _ in item }

        let locationRepository = LocationRequestLocationRepository()
        locationRepository.findHandler = { _, _ in location }

        let userRepository = LocationRequestUserRepository()
        userRepository.findHandler = { _, id in
            id == accountant.id ? accountant : nil
        }

        let requestRepository = LocationRequestRepository()
        var saved: ItemLocationRequest?
        requestRepository.findRequestedHandler = { _, _, _, _ in nil }
        requestRepository.saveHandler = { _, request in saved = request }

        let journalService = LocationRequestItemJournalService()
        let service = DefaultItemLocationRequestService(
            repositories: makeLocationRequestRepositoryContainer(
                itemRepository: itemRepository,
                locationRepository: locationRepository,
                userRepository: userRepository,
                requestRepository: requestRepository,
                itemLocationRepository: LocationRequestItemLocationRepository()
            ),
            itemJournalService: journalService
        )

        let result = try await service.create(
            data: ItemLocationRequestCreateData(
                itemID: try item.requireID(),
                locationID: try location.requireID(),
                requestedToUserID: try accountant.requireID()
            ),
            context: ServiceContext(db: app.db, currentUser: employee)
        )

        XCTAssertEqual(result.status, .requested)
        XCTAssertEqual(result.requestedToUserID, try accountant.requireID())
        XCTAssertEqual(saved?.requestedToUserID, try accountant.requireID())
        XCTAssertEqual(journalService.recordedEvents.count, 1)
        XCTAssertEqual(journalService.recordedEvents.first?.eventType, ItemJournalEventType.locationRequestCreated)
    }

    func testResponsibleMRPCannotCreateRequestBecauseDirectAllowed() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeLocationRequestUser(role: .materiallyResponsiblePerson)
        let item = makeLocationRequestItem(responsibleUserID: try mrp.requireID())
        let location = makeLocationRequestLocation()

        let itemRepository = LocationRequestItemRepository()
        itemRepository.findHandler = { _, _ in item }

        let locationRepository = LocationRequestLocationRepository()
        locationRepository.findHandler = { _, _ in location }

        let service = DefaultItemLocationRequestService(
            repositories: makeLocationRequestRepositoryContainer(
                itemRepository: itemRepository,
                locationRepository: locationRepository,
                userRepository: LocationRequestUserRepository(),
                requestRepository: LocationRequestRepository(),
                itemLocationRepository: LocationRequestItemLocationRepository()
            ),
            itemJournalService: LocationRequestItemJournalService()
        )

        do {
            _ = try await service.create(
                data: ItemLocationRequestCreateData(
                    itemID: try item.requireID(),
                    locationID: try location.requireID(),
                    requestedToUserID: UUID()
                ),
                context: ServiceContext(db: app.db, currentUser: mrp)
            )
            XCTFail("Expected conflict for direct-capable user")
        } catch let error as DomainError {
            guard case .conflict = error else {
                XCTFail("Expected conflict")
                return
            }
        }
    }

    func testNonPrivilegedUserGetsEmptyIncomingList() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let employee = makeLocationRequestUser(role: .employee)
        let service = DefaultItemLocationRequestService(
            repositories: makeLocationRequestRepositoryContainer(
                itemRepository: LocationRequestItemRepository(),
                locationRepository: LocationRequestLocationRepository(),
                userRepository: LocationRequestUserRepository(),
                requestRepository: LocationRequestRepository(),
                itemLocationRepository: LocationRequestItemLocationRepository()
            ),
            itemJournalService: LocationRequestItemJournalService()
        )

        let result = try await service.incoming(context: ServiceContext(db: app.db, currentUser: employee))
        XCTAssertTrue(result.isEmpty)
    }

    func testAccountantApprovesLocationRequestAndAppliesLocation() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let accountant = makeLocationRequestUser(role: .accountant)
        let requester = makeLocationRequestUser(role: .employee)
        let item = makeLocationRequestItem(responsibleUserID: UUID())
        let location = makeLocationRequestLocation()

        let request = ItemLocationRequest(
            itemID: try item.requireID(),
            locationID: try location.requireID(),
            requesterUserID: try requester.requireID(),
            requestedToUserID: try accountant.requireID()
        )
        request.id = UUID()

        let itemRepository = LocationRequestItemRepository()
        itemRepository.findHandler = { _, _ in item }

        let locationRepository = LocationRequestLocationRepository()
        locationRepository.findHandler = { _, _ in location }

        let requestRepository = LocationRequestRepository()
        requestRepository.findHandler = { _, _ in request }
        var savedRequest: ItemLocationRequest?
        requestRepository.saveHandler = { _, value in savedRequest = value }

        let itemLocationRepository = LocationRequestItemLocationRepository()
        var savedLocation: ItemLocation?
        itemLocationRepository.findHandler = { _, _, _ in nil }
        itemLocationRepository.saveHandler = { _, value in savedLocation = value }

        let journalService = LocationRequestItemJournalService()
        let service = DefaultItemLocationRequestService(
            repositories: makeLocationRequestRepositoryContainer(
                itemRepository: itemRepository,
                locationRepository: locationRepository,
                userRepository: LocationRequestUserRepository(),
                requestRepository: requestRepository,
                itemLocationRepository: itemLocationRepository
            ),
            itemJournalService: journalService
        )

        let approved = try await service.approve(
            data: ItemLocationRequestApproveData(requestID: try request.requireID()),
            context: ServiceContext(db: app.db, currentUser: accountant)
        )

        XCTAssertEqual(approved.status, .approved)
        XCTAssertEqual(savedRequest?.approvedByUserID, try accountant.requireID())
        XCTAssertEqual(savedLocation?.$item.id, try item.requireID())
        XCTAssertEqual(savedLocation?.$location.id, try location.requireID())
        XCTAssertEqual(journalService.recordedEvents.count, 1)
        XCTAssertEqual(journalService.recordedEvents.first?.eventType, ItemJournalEventType.locationRequestApproved)
    }

    func testResponsibleMRPCanApproveOwnItemLocationRequest() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let mrp = makeLocationRequestUser(role: .materiallyResponsiblePerson)
        let requester = makeLocationRequestUser(role: .employee)
        let item = makeLocationRequestItem(responsibleUserID: try mrp.requireID())
        let location = makeLocationRequestLocation()

        let request = ItemLocationRequest(
            itemID: try item.requireID(),
            locationID: try location.requireID(),
            requesterUserID: try requester.requireID(),
            requestedToUserID: try mrp.requireID()
        )
        request.id = UUID()

        let itemRepository = LocationRequestItemRepository()
        itemRepository.findHandler = { _, _ in item }

        let locationRepository = LocationRequestLocationRepository()
        locationRepository.findHandler = { _, _ in location }

        let requestRepository = LocationRequestRepository()
        requestRepository.findHandler = { _, _ in request }
        var savedRequest: ItemLocationRequest?
        requestRepository.saveHandler = { _, value in savedRequest = value }

        let itemLocationRepository = LocationRequestItemLocationRepository()
        itemLocationRepository.findHandler = { _, _, _ in nil }

        let service = DefaultItemLocationRequestService(
            repositories: makeLocationRequestRepositoryContainer(
                itemRepository: itemRepository,
                locationRepository: locationRepository,
                userRepository: LocationRequestUserRepository(),
                requestRepository: requestRepository,
                itemLocationRepository: itemLocationRepository
            ),
            itemJournalService: LocationRequestItemJournalService()
        )

        let approved = try await service.approve(
            data: ItemLocationRequestApproveData(requestID: try request.requireID()),
            context: ServiceContext(db: app.db, currentUser: mrp)
        )

        XCTAssertEqual(approved.status, .approved)
        XCTAssertEqual(savedRequest?.approvedByUserID, try mrp.requireID())
    }
}

private func makeLocationRequestRepositoryContainer(
    itemRepository: any ItemRepository,
    locationRepository: any LocationRepository,
    userRepository: any UserRepository,
    requestRepository: any ItemLocationRequestRepository,
    itemLocationRepository: any ItemLocationRepository
) -> RepositoryContainer {
    RepositoryContainer(
        itemRepository: itemRepository,
        userRepository: userRepository,
        userItemRepository: LocationRequestUserItemRepository(),
        itemLocationRepository: itemLocationRepository,
        itemLocationRequestRepository: requestRepository,
        inventoryRequestRepository: LocationRequestInventoryRequestRepository(),
        inventoryRequestItemRepository: LocationRequestInventoryRequestItemRepository(),
        itemJournalRepository: LocationRequestItemJournalRepository(),
        brokenItemRepository: LocationRequestBrokenItemRepository(),
        itemCategoryRepository: LocationRequestItemCategoryRepository(),
        locationRepository: locationRepository,
        itemParameterRepository: LocationRequestItemParameterRepository(),
        userTokenRepository: LocationRequestUserTokenRepository()
    )
}

private func makeLocationRequestUser(role: UserRole) -> User {
    let user = User(
        login: UUID().uuidString,
        passwordHash: "hash",
        fullName: "Location Request User",
        age: 28,
        position: "Engineer",
        role: role
    )
    user.id = UUID()
    return user
}

private func makeLocationRequestItem(responsibleUserID: UUID) -> Item {
    let item = Item(number: "IT-\(UUID().uuidString)", name: "Item", responsibleUserID: responsibleUserID)
    item.id = UUID()
    return item
}

private func makeLocationRequestLocation() -> Location {
    let location = Location(name: "WH-A", kind: .warehouse)
    location.id = UUID()
    return location
}

private final class LocationRequestItemRepository: ItemRepository {
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
    func find(id: UUID, on db: Database) async throws -> Item? { try findHandler?(db, id) }
    func save(_ item: Item, on db: Database) async throws {}
    func delete(_ item: Item, on db: Database) async throws {}
}

private final class LocationRequestLocationRepository: LocationRepository {
    var findHandler: ((Database, UUID) throws -> Location?)?

    func list(on db: Database) async throws -> [Location] { [] }
    func find(id: UUID, on db: Database) async throws -> Location? { try findHandler?(db, id) }
    func save(_ location: Location, on db: Database) async throws {}
    func delete(_ location: Location, on db: Database) async throws {}
}

private final class LocationRequestUserRepository: UserRepository {
    var findHandler: ((Database, UUID) throws -> User?)?

    func find(id: UUID, on db: Database) async throws -> User? { try findHandler?(db, id) }
    func findByLogin(_ login: String, on db: Database) async throws -> User? { nil }
    func list(page: Int, per: Int, on db: Database) async throws -> [User] { [] }
    func count(on db: Database) async throws -> Int { 0 }
    func listMateriallyResponsible(on db: Database) async throws -> [User] { [] }
    func save(_ user: User, on db: Database) async throws {}
}

private final class LocationRequestRepository: ItemLocationRequestRepository {
    var findHandler: ((Database, UUID) throws -> ItemLocationRequest?)?
    var findRequestedHandler: ((Database, UUID, UUID, UUID) throws -> ItemLocationRequest?)?
    var listIncomingHandler: ((Database, UUID) throws -> [ItemLocationRequest])?
    var saveHandler: ((Database, ItemLocationRequest) throws -> Void)?

    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest? {
        try findHandler?(db, id)
    }

    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest? {
        try findRequestedHandler?(db, itemID, locationID, requesterUserID)
    }

    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest] {
        try listIncomingHandler?(db, userID) ?? []
    }

    func save(_ request: ItemLocationRequest, on db: Database) async throws {
        try saveHandler?(db, request)
    }
}

private final class LocationRequestItemLocationRepository: ItemLocationRepository {
    var findHandler: ((Database, UUID, UUID) throws -> ItemLocation?)?
    var saveHandler: ((Database, ItemLocation) throws -> Void)?

    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? {
        try findHandler?(db, itemID, locationID)
    }

    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] { [] }

    func save(_ itemLocation: ItemLocation, on db: Database) async throws {
        try saveHandler?(db, itemLocation)
    }
}

private struct LocationRequestUserItemRepository: UserItemRepository {
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

private struct LocationRequestItemJournalRepository: ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws {}
    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] { [] }
    func count(itemID: UUID, on db: Database) async throws -> Int { 0 }
}

private final class LocationRequestItemJournalService: ItemJournalService {
    private(set) var recordedEvents: [ItemJournalRecordData] = []

    func list(itemID: UUID, page: Int?, per: Int?, context: ServiceContext) async throws -> ItemJournalPageResponse {
        ItemJournalPageResponse(messages: [], page: 1, per: 20, total: 0, totalPages: 1, hasNext: false)
    }

    func record(data: ItemJournalRecordData, context: ServiceContext) async throws {
        recordedEvents.append(data)
    }
}

private struct LocationRequestInventoryRequestRepository: InventoryRequestRepository {
    func create(_ request: InventoryRequest, on db: Database) async throws {}
    func find(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func save(_ request: InventoryRequest, on db: Database) async throws {}
    func findActiveConflictingItemIDs(itemIDs: [UUID], excludingRequestID: UUID?, on db: Database) async throws -> Set<UUID> { [] }
}

private struct LocationRequestInventoryRequestItemRepository: InventoryRequestItemRepository {
    func create(_ item: InventoryRequestItem, on db: Database) async throws {}
    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem? { nil }
    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem] { [] }
    func deleteByRequestID(requestID: UUID, on db: Database) async throws {}
    func save(_ item: InventoryRequestItem, on db: Database) async throws {}
}

private struct LocationRequestBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool { false }
    func listWithItem(on db: Database) async throws -> [BrokenItem] { [] }
    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem] { [] }
    func save(_ brokenItem: BrokenItem, on db: Database) async throws {}
}

private struct LocationRequestItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] { [] }
    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount] { [] }
    func exists(id: UUID, on db: Database) async throws -> Bool { false }
    func find(id: UUID, on db: Database) async throws -> ItemCategory? { nil }
    func save(_ category: ItemCategory, on db: Database) async throws {}
    func delete(_ category: ItemCategory, on db: Database) async throws {}
}

private struct LocationRequestItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] { [] }
    func find(id: UUID, on db: Database) async throws -> ItemParameter? { nil }
    func save(_ parameter: ItemParameter, on db: Database) async throws {}
    func delete(_ parameter: ItemParameter, on db: Database) async throws {}
}

private struct LocationRequestUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {}
    func deleteByUserID(_ userID: UUID, on db: Database) async throws {}
}
