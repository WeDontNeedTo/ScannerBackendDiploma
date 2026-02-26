import Fluent
@testable import App
import XCTVapor

final class ItemJournalServiceTests: XCTestCase {
    func testListReturnsEmptyPageWhenNoEvents() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let item = makeItem()
        let itemRepository = JournalTestItemRepository()
        itemRepository.findHandler = { _, id in
            id == item.id ? item : nil
        }

        let journalRepository = JournalTestItemJournalRepository()
        journalRepository.countHandler = { _, _ in 0 }
        journalRepository.listHandler = { _, _, _, _ in [] }

        let service = DefaultItemJournalService(repositories: makeJournalRepositoryContainer(
            itemRepository: itemRepository,
            journalRepository: journalRepository
        ))

        let response = try await service.list(
            itemID: try item.requireID(),
            page: nil,
            per: nil,
            context: ServiceContext(db: app.db, currentUser: nil)
        )

        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.per, 20)
        XCTAssertEqual(response.total, 0)
        XCTAssertEqual(response.totalPages, 1)
        XCTAssertEqual(response.hasNext, false)
        XCTAssertTrue(response.messages.isEmpty)
        XCTAssertEqual(journalRepository.lastOffset, 0)
        XCTAssertEqual(journalRepository.lastLimit, 20)
    }

    func testListClampsPageAndPer() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let item = makeItem()
        let itemRepository = JournalTestItemRepository()
        itemRepository.findHandler = { _, id in
            id == item.id ? item : nil
        }

        let journalRepository = JournalTestItemJournalRepository()
        journalRepository.countHandler = { _, _ in 250 }
        journalRepository.listHandler = { _, _, _, _ in [] }

        let service = DefaultItemJournalService(repositories: makeJournalRepositoryContainer(
            itemRepository: itemRepository,
            journalRepository: journalRepository
        ))

        let response = try await service.list(
            itemID: try item.requireID(),
            page: 10,
            per: 500,
            context: ServiceContext(db: app.db, currentUser: nil)
        )

        XCTAssertEqual(response.page, 3)
        XCTAssertEqual(response.per, 100)
        XCTAssertEqual(response.total, 250)
        XCTAssertEqual(response.totalPages, 3)
        XCTAssertEqual(response.hasNext, false)
        XCTAssertEqual(journalRepository.lastOffset, 200)
        XCTAssertEqual(journalRepository.lastLimit, 100)
    }

    func testListRejectsInvalidPagination() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let item = makeItem()
        let itemRepository = JournalTestItemRepository()
        itemRepository.findHandler = { _, id in
            id == item.id ? item : nil
        }

        let journalRepository = JournalTestItemJournalRepository()
        let service = DefaultItemJournalService(repositories: makeJournalRepositoryContainer(
            itemRepository: itemRepository,
            journalRepository: journalRepository
        ))

        do {
            _ = try await service.list(
                itemID: try item.requireID(),
                page: 0,
                per: 20,
                context: ServiceContext(db: app.db, currentUser: nil)
            )
            XCTFail("Expected badRequest for page=0")
        } catch let error as DomainError {
            guard case .badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }

        do {
            _ = try await service.list(
                itemID: try item.requireID(),
                page: 1,
                per: 0,
                context: ServiceContext(db: app.db, currentUser: nil)
            )
            XCTFail("Expected badRequest for per=0")
        } catch let error as DomainError {
            guard case .badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }
    }

    func testRecordStoresMessageAndType() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let item = makeItem()
        let itemRepository = JournalTestItemRepository()
        itemRepository.findHandler = { _, id in
            id == item.id ? item : nil
        }

        let journalRepository = JournalTestItemJournalRepository()
        let service = DefaultItemJournalService(repositories: makeJournalRepositoryContainer(
            itemRepository: itemRepository,
            journalRepository: journalRepository
        ))

        try await service.record(
            data: ItemJournalRecordData(
                itemID: try item.requireID(),
                actorUserID: UUID(),
                eventType: ItemJournalEventType.grabRequested,
                message: "Тестовое сообщение"
            ),
            context: ServiceContext(db: app.db, currentUser: nil)
        )

        XCTAssertEqual(journalRepository.createdEvent?.eventType, ItemJournalEventType.grabRequested)
        XCTAssertEqual(journalRepository.createdEvent?.message, "Тестовое сообщение")
        XCTAssertEqual(journalRepository.createdEvent?.$item.id, item.id)
    }
}

private func makeItem() -> Item {
    let item = Item(number: "SKU-\(UUID().uuidString)", name: "Item", responsibleUserID: UUID())
    item.id = UUID()
    return item
}

private func makeJournalRepositoryContainer(
    itemRepository: any ItemRepository,
    journalRepository: any ItemJournalRepository
) -> RepositoryContainer {
    RepositoryContainer(
        itemRepository: itemRepository,
        userRepository: JournalTestUserRepository(),
        userItemRepository: JournalTestUserItemRepository(),
        itemLocationRepository: JournalTestItemLocationRepository(),
        itemLocationRequestRepository: JournalTestItemLocationRequestRepository(),
        inventoryRequestRepository: JournalTestInventoryRequestRepository(),
        inventoryRequestItemRepository: JournalTestInventoryRequestItemRepository(),
        itemJournalRepository: journalRepository,
        brokenItemRepository: JournalTestBrokenItemRepository(),
        itemCategoryRepository: JournalTestItemCategoryRepository(),
        locationRepository: JournalTestLocationRepository(),
        itemParameterRepository: JournalTestItemParameterRepository(),
        userTokenRepository: JournalTestUserTokenRepository()
    )
}

private final class JournalTestItemRepository: ItemRepository {
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

private final class JournalTestItemJournalRepository: ItemJournalRepository {
    var createdEvent: ItemJournalEvent?
    var lastOffset: Int?
    var lastLimit: Int?

    var countHandler: ((Database, UUID) throws -> Int)?
    var listHandler: ((Database, UUID, Int, Int) throws -> [ItemJournalEvent])?

    func create(_ event: ItemJournalEvent, on db: Database) async throws {
        createdEvent = event
    }

    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] {
        lastOffset = offset
        lastLimit = limit
        return try listHandler?(db, itemID, offset, limit) ?? []
    }

    func count(itemID: UUID, on db: Database) async throws -> Int {
        try countHandler?(db, itemID) ?? 0
    }
}

private struct JournalTestUserRepository: UserRepository {
    func find(id: UUID, on db: Database) async throws -> User? { nil }
    func findByLogin(_ login: String, on db: Database) async throws -> User? { nil }
    func list(page: Int, per: Int, on db: Database) async throws -> [User] { [] }
    func count(on db: Database) async throws -> Int { 0 }
    func listMateriallyResponsible(on db: Database) async throws -> [User] { [] }
    func save(_ user: User, on db: Database) async throws {}
}

private struct JournalTestUserItemRepository: UserItemRepository {
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

private struct JournalTestItemLocationRepository: ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? { nil }
    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] { [] }
    func save(_ itemLocation: ItemLocation, on db: Database) async throws {}
}

private struct JournalTestItemLocationRequestRepository: ItemLocationRequestRepository {
    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest] { [] }
    func save(_ request: ItemLocationRequest, on db: Database) async throws {}
}

private struct JournalTestInventoryRequestRepository: InventoryRequestRepository {
    func create(_ request: InventoryRequest, on db: Database) async throws {}
    func find(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func save(_ request: InventoryRequest, on db: Database) async throws {}
    func findActiveConflictingItemIDs(itemIDs: [UUID], excludingRequestID: UUID?, on db: Database) async throws -> Set<UUID> { [] }
}

private struct JournalTestInventoryRequestItemRepository: InventoryRequestItemRepository {
    func create(_ item: InventoryRequestItem, on db: Database) async throws {}
    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem? { nil }
    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem] { [] }
    func deleteByRequestID(requestID: UUID, on db: Database) async throws {}
    func save(_ item: InventoryRequestItem, on db: Database) async throws {}
}

private struct JournalTestBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool { false }
    func listWithItem(on db: Database) async throws -> [BrokenItem] { [] }
    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem] { [] }
    func save(_ brokenItem: BrokenItem, on db: Database) async throws {}
}

private struct JournalTestItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] { [] }
    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount] { [] }
    func exists(id: UUID, on db: Database) async throws -> Bool { false }
    func find(id: UUID, on db: Database) async throws -> ItemCategory? { nil }
    func save(_ category: ItemCategory, on db: Database) async throws {}
    func delete(_ category: ItemCategory, on db: Database) async throws {}
}

private struct JournalTestLocationRepository: LocationRepository {
    func list(on db: Database) async throws -> [Location] { [] }
    func find(id: UUID, on db: Database) async throws -> Location? { nil }
    func save(_ location: Location, on db: Database) async throws {}
    func delete(_ location: Location, on db: Database) async throws {}
}

private struct JournalTestItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] { [] }
    func find(id: UUID, on db: Database) async throws -> ItemParameter? { nil }
    func save(_ parameter: ItemParameter, on db: Database) async throws {}
    func delete(_ parameter: ItemParameter, on db: Database) async throws {}
}

private struct JournalTestUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {}
    func deleteByUserID(_ userID: UUID, on db: Database) async throws {}
}
