import Fluent
@testable import App
import XCTVapor

final class DashboardServiceTests: XCTestCase {
    func testEmployeeGetsUnavailableZeroBalanceWidget() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let user = makeDashboardUser(role: .employee)
        let itemRepository = MockDashboardItemRepository()
        var queried = false
        itemRepository.dashboardBalanceStatsHandler = { _, _ in
            queried = true
            return DashboardBalanceStats(ownedItemsCount: 99, totalBalanceRub: Decimal(string: "9999.99")!, items: [])
        }

        let service = DefaultDashboardService(
            repositories: makeDashboardRepositoryContainer(itemRepository: itemRepository)
        )
        let response = try await service.dashboard(
            context: ServiceContext(db: app.db, currentUser: user)
        )

        XCTAssertEqual(response.widgets.count, 3)
        XCTAssertEqual(response.widgets[0].type, .balanceStatics)
        XCTAssertEqual(response.widgets[0].order, 1)
        XCTAssertFalse(response.widgets[0].isAvailable)
        XCTAssertEqual(response.widgets[0].payload.totalBalanceRub, Decimal.zero)
        XCTAssertEqual(response.widgets[0].payload.currency, "RUB")
        XCTAssertEqual(response.widgets[2].type, .brokenItems)
        XCTAssertFalse(response.widgets[2].isAvailable)
        XCTAssertFalse(queried)
    }

    func testMRPWithoutItemsGetsUnavailableZeroBalanceWidget() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let user = makeDashboardUser(role: .materiallyResponsiblePerson)
        let itemRepository = MockDashboardItemRepository()
        itemRepository.dashboardBalanceStatsHandler = { _, _ in
            DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: Decimal(string: "2500.00")!, items: [])
        }

        let service = DefaultDashboardService(
            repositories: makeDashboardRepositoryContainer(itemRepository: itemRepository)
        )
        let response = try await service.dashboard(
            context: ServiceContext(db: app.db, currentUser: user)
        )

        XCTAssertFalse(response.widgets[0].isAvailable)
        XCTAssertEqual(response.widgets[0].payload.totalBalanceRub, Decimal.zero)
    }

    func testMRPWithItemsGetsAvailableSumIgnoringNullsFromRepository() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let user = makeDashboardUser(role: .materiallyResponsiblePerson)
        let itemRepository = MockDashboardItemRepository()
        itemRepository.dashboardBalanceStatsHandler = { _, _ in
            DashboardBalanceStats(ownedItemsCount: 3, totalBalanceRub: Decimal(string: "1200.75")!, items: [])
        }

        let service = DefaultDashboardService(
            repositories: makeDashboardRepositoryContainer(itemRepository: itemRepository)
        )
        let response = try await service.dashboard(
            context: ServiceContext(db: app.db, currentUser: user)
        )

        XCTAssertTrue(response.widgets[0].isAvailable)
        XCTAssertEqual(response.widgets[0].payload.totalBalanceRub, Decimal(string: "1200.75")!)
    }

    func testAccountantWithoutItemsIsAvailableWithZeroBalance() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let user = makeDashboardUser(role: .accountant)
        let itemRepository = MockDashboardItemRepository()
        itemRepository.dashboardBalanceStatsHandler = { _, _ in
            DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero, items: [])
        }

        let service = DefaultDashboardService(
            repositories: makeDashboardRepositoryContainer(itemRepository: itemRepository)
        )
        let response = try await service.dashboard(
            context: ServiceContext(db: app.db, currentUser: user)
        )

        XCTAssertTrue(response.widgets[0].isAvailable)
        XCTAssertEqual(response.widgets[0].payload.totalBalanceRub, Decimal.zero)
    }

    func testAdminUsesOwnOnlyBalanceWhenHasItems() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let user = makeDashboardUser(role: .admin)
        let itemRepository = MockDashboardItemRepository()
        itemRepository.dashboardBalanceStatsHandler = { _, userID in
            XCTAssertEqual(userID, user.id)
            return DashboardBalanceStats(ownedItemsCount: 2, totalBalanceRub: Decimal(string: "999.99")!, items: [])
        }

        let service = DefaultDashboardService(
            repositories: makeDashboardRepositoryContainer(itemRepository: itemRepository)
        )
        let response = try await service.dashboard(
            context: ServiceContext(db: app.db, currentUser: user)
        )

        XCTAssertTrue(response.widgets[0].isAvailable)
        XCTAssertEqual(response.widgets[0].payload.totalBalanceRub, Decimal(string: "999.99")!)
    }

    func testDashboardRouteRequiresAuthentication() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/dashboard") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
}

private func makeDashboardUser(role: UserRole) -> User {
    let user = User(
        login: UUID().uuidString,
        passwordHash: "hash",
        fullName: "Dashboard User",
        age: 30,
        position: "Engineer",
        role: role
    )
    user.id = UUID()
    return user
}

private func makeDashboardRepositoryContainer(itemRepository: any ItemRepository) -> RepositoryContainer {
    RepositoryContainer(
        itemRepository: itemRepository,
        userRepository: DashboardUserRepository(),
        userItemRepository: DashboardUserItemRepository(),
        itemLocationRepository: DashboardItemLocationRepository(),
        itemLocationRequestRepository: DashboardItemLocationRequestRepository(),
        inventoryRequestRepository: DashboardInventoryRequestRepository(),
        inventoryRequestItemRepository: DashboardInventoryRequestItemRepository(),
        itemJournalRepository: DashboardItemJournalRepository(),
        brokenItemRepository: DashboardBrokenItemRepository(),
        itemCategoryRepository: DashboardItemCategoryRepository(),
        locationRepository: DashboardLocationRepository(),
        itemParameterRepository: DashboardItemParameterRepository(),
        userTokenRepository: DashboardUserTokenRepository()
    )
}

private final class MockDashboardItemRepository: ItemRepository {
    var dashboardBalanceStatsHandler: ((Database, UUID) throws -> DashboardBalanceStats)?

    func listWithRelations(on db: Database) async throws -> [Item] { [] }
    func findWithRelations(id: UUID, on db: Database) async throws -> Item? { nil }
    func findWithRelations(number: String, on db: Database) async throws -> Item? { nil }
    func search(with data: ItemSearchData, on db: Database) async throws -> [Item] { [] }
    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats {
        try dashboardBalanceStatsHandler?(db, responsibleUserID)
            ?? DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero, items: [])
    }
    func countByResponsibleUser(responsibleUserID: UUID, on db: Database) async throws -> Int { 0 }
    func listByResponsibleUserWithRelations(responsibleUserID: UUID, on db: Database) async throws -> [Item] { [] }
    func findAllByIDs(_ ids: [UUID], on db: Database) async throws -> [Item] { [] }
    func findAllByIDsWithRelations(_ ids: [UUID], on db: Database) async throws -> [Item] { [] }
    func saveAll(_ items: [Item], on db: Database) async throws {}
    func find(id: UUID, on db: Database) async throws -> Item? { nil }
    func save(_ item: Item, on db: Database) async throws {}
    func delete(_ item: Item, on db: Database) async throws {}
}

private struct DashboardUserRepository: UserRepository {
    func find(id: UUID, on db: Database) async throws -> User? { nil }
    func findByLogin(_ login: String, on db: Database) async throws -> User? { nil }
    func list(page: Int, per: Int, on db: Database) async throws -> [User] { [] }
    func count(on db: Database) async throws -> Int { 0 }
    func listMateriallyResponsible(on db: Database) async throws -> [User] { [] }
    func save(_ user: User, on db: Database) async throws {}
}

private struct DashboardUserItemRepository: UserItemRepository {
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

private struct DashboardItemLocationRepository: ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? { nil }
    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] { [] }
    func save(_ itemLocation: ItemLocation, on db: Database) async throws {}
}

private struct DashboardItemLocationRequestRepository: ItemLocationRequestRepository {
    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest] { [] }
    func save(_ request: ItemLocationRequest, on db: Database) async throws {}
}

private struct DashboardInventoryRequestRepository: InventoryRequestRepository {
    func create(_ request: InventoryRequest, on db: Database) async throws {}
    func find(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func save(_ request: InventoryRequest, on db: Database) async throws {}
    func findActiveConflictingItemIDs(itemIDs: [UUID], excludingRequestID: UUID?, on db: Database) async throws -> Set<UUID> { [] }
}

private struct DashboardInventoryRequestItemRepository: InventoryRequestItemRepository {
    func create(_ item: InventoryRequestItem, on db: Database) async throws {}
    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem? { nil }
    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem] { [] }
    func deleteByRequestID(requestID: UUID, on db: Database) async throws {}
    func save(_ item: InventoryRequestItem, on db: Database) async throws {}
}

private struct DashboardItemJournalRepository: ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws {}
    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] { [] }
    func count(itemID: UUID, on db: Database) async throws -> Int { 0 }
}

private struct DashboardBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool { false }
    func listWithItem(on db: Database) async throws -> [BrokenItem] { [] }
    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem] { [] }
    func save(_ brokenItem: BrokenItem, on db: Database) async throws {}
}

private struct DashboardItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] { [] }
    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount] { [] }
    func exists(id: UUID, on db: Database) async throws -> Bool { false }
    func find(id: UUID, on db: Database) async throws -> ItemCategory? { nil }
    func save(_ category: ItemCategory, on db: Database) async throws {}
    func delete(_ category: ItemCategory, on db: Database) async throws {}
}

private struct DashboardLocationRepository: LocationRepository {
    func list(on db: Database) async throws -> [Location] { [] }
    func find(id: UUID, on db: Database) async throws -> Location? { nil }
    func save(_ location: Location, on db: Database) async throws {}
    func delete(_ location: Location, on db: Database) async throws {}
}

private struct DashboardItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] { [] }
    func find(id: UUID, on db: Database) async throws -> ItemParameter? { nil }
    func save(_ parameter: ItemParameter, on db: Database) async throws {}
    func delete(_ parameter: ItemParameter, on db: Database) async throws {}
}

private struct DashboardUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {}
    func deleteByUserID(_ userID: UUID, on db: Database) async throws {}
}
