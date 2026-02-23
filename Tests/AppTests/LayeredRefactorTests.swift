import Fluent
@testable import App
import XCTVapor

final class LayeredRefactorTests: XCTestCase {
    func testProtectedItemsRouteRequiresAuth() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/items") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testEmployeeCreateUserItemProducesRequestedStatus() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let employee = makeUser(role: .employee)
        let mrp = makeUser(role: .materiallyResponsiblePerson)
        let item = makeItem(responsibleUserID: try mrp.requireID())

        let itemRepository = MockItemRepository()
        itemRepository.findHandler = { _, id in
            id == (try item.requireID()) ? item : nil
        }

        let userRepository = MockUserRepository()
        userRepository.findHandler = { _, id in
            id == (try mrp.requireID()) ? mrp : nil
        }

        let userItemRepository = MockUserItemRepository()
        var saved: UserItem?
        userItemRepository.findByItemIDHandler = { _, _ in nil }
        userItemRepository.saveHandler = { _, userItem in
            saved = userItem
        }

        let service = DefaultUserItemService(repositories: makeRepositoryContainer(
            itemRepository: itemRepository,
            userRepository: userRepository,
            userItemRepository: userItemRepository
        ), itemJournalService: MockItemJournalService())

        let result = try await service.create(
            data: UserItemCreateData(itemID: try item.requireID(), requestedToUserID: nil),
            context: ServiceContext(db: app.db, currentUser: employee)
        )

        XCTAssertEqual(result.kind, .create)
        XCTAssertEqual(result.value.status, .requested)
        XCTAssertEqual(result.value.requestedToUserID, try mrp.requireID())
        XCTAssertNil(result.value.approvedByUserID)
        XCTAssertEqual(saved?.status, .requested)
    }

    func testAccountantCreateUserItemBypassesRequestFlow() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let accountant = makeUser(role: .accountant)
        let mrp = makeUser(role: .materiallyResponsiblePerson)
        let item = makeItem(responsibleUserID: try mrp.requireID())

        let itemRepository = MockItemRepository()
        itemRepository.findHandler = { _, id in
            id == (try item.requireID()) ? item : nil
        }

        let userRepository = MockUserRepository()
        userRepository.findHandler = { _, _ in nil }

        let userItemRepository = MockUserItemRepository()
        userItemRepository.findByItemIDHandler = { _, _ in nil }

        let service = DefaultUserItemService(repositories: makeRepositoryContainer(
            itemRepository: itemRepository,
            userRepository: userRepository,
            userItemRepository: userItemRepository
        ), itemJournalService: MockItemJournalService())

        let result = try await service.create(
            data: UserItemCreateData(itemID: try item.requireID(), requestedToUserID: nil),
            context: ServiceContext(db: app.db, currentUser: accountant)
        )

        XCTAssertEqual(result.kind, .create)
        XCTAssertEqual(result.value.status, .approved)
        XCTAssertEqual(result.value.approvedByUserID, try accountant.requireID())
        XCTAssertNil(result.value.requestedToUserID)
    }
}

private func makeUser(role: UserRole) -> User {
    let user = User(
        login: UUID().uuidString,
        passwordHash: "hash",
        fullName: "Test User",
        age: 30,
        position: "Engineer",
        role: role
    )
    user.id = UUID()
    return user
}

private func makeItem(responsibleUserID: UUID) -> Item {
    let item = Item(number: "SKU-\(UUID().uuidString)", name: "Item", responsibleUserID: responsibleUserID)
    item.id = UUID()
    return item
}

private func makeRepositoryContainer(
    itemRepository: any ItemRepository,
    userRepository: any UserRepository,
    userItemRepository: any UserItemRepository
) -> RepositoryContainer {
    RepositoryContainer(
        itemRepository: itemRepository,
        userRepository: userRepository,
        userItemRepository: userItemRepository,
        itemLocationRepository: MockItemLocationRepository(),
        itemJournalRepository: MockItemJournalRepository(),
        brokenItemRepository: MockBrokenItemRepository(),
        itemCategoryRepository: MockItemCategoryRepository(),
        locationRepository: MockLocationRepository(),
        itemParameterRepository: MockItemParameterRepository(),
        userTokenRepository: MockUserTokenRepository()
    )
}

private final class MockItemRepository: ItemRepository {
    var listWithRelationsHandler: ((Database) throws -> [Item])?
    var findWithRelationsByIDHandler: ((Database, UUID) throws -> Item?)?
    var findWithRelationsByNumberHandler: ((Database, String) throws -> Item?)?
    var searchHandler: ((Database, ItemSearchData) throws -> [Item])?
    var dashboardBalanceStatsHandler: ((Database, UUID) throws -> DashboardBalanceStats)?
    var findHandler: ((Database, UUID) throws -> Item?)?
    var saveHandler: ((Database, Item) throws -> Void)?
    var deleteHandler: ((Database, Item) throws -> Void)?

    func listWithRelations(on db: Database) async throws -> [Item] {
        try listWithRelationsHandler?(db) ?? []
    }

    func findWithRelations(id: UUID, on db: Database) async throws -> Item? {
        try findWithRelationsByIDHandler?(db, id)
    }

    func findWithRelations(number: String, on db: Database) async throws -> Item? {
        try findWithRelationsByNumberHandler?(db, number)
    }

    func search(with data: ItemSearchData, on db: Database) async throws -> [Item] {
        try searchHandler?(db, data) ?? []
    }

    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats {
        try dashboardBalanceStatsHandler?(db, responsibleUserID)
            ?? DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero)
    }

    func find(id: UUID, on db: Database) async throws -> Item? {
        try findHandler?(db, id)
    }

    func save(_ item: Item, on db: Database) async throws {
        try saveHandler?(db, item)
    }

    func delete(_ item: Item, on db: Database) async throws {
        try deleteHandler?(db, item)
    }
}

private final class MockUserRepository: UserRepository {
    var findHandler: ((Database, UUID) throws -> User?)?
    var findByLoginHandler: ((Database, String) throws -> User?)?
    var listMateriallyResponsibleHandler: ((Database) throws -> [User])?
    var saveHandler: ((Database, User) throws -> Void)?

    func find(id: UUID, on db: Database) async throws -> User? {
        try findHandler?(db, id)
    }

    func findByLogin(_ login: String, on db: Database) async throws -> User? {
        try findByLoginHandler?(db, login)
    }

    func listMateriallyResponsible(on db: Database) async throws -> [User] {
        try listMateriallyResponsibleHandler?(db) ?? []
    }

    func save(_ user: User, on db: Database) async throws {
        try saveHandler?(db, user)
    }
}

private final class MockUserItemRepository: UserItemRepository {
    var listForUserHandler: ((Database, UUID) throws -> [UserItem])?
    var listAllWithItemHandler: ((Database) throws -> [UserItem])?
    var listIncomingHandler: ((Database, UUID) throws -> [UserItem])?
    var findByIDHandler: ((Database, UUID) throws -> UserItem?)?
    var findWithItemHandler: ((Database, UUID) throws -> UserItem?)?
    var findByItemIDHandler: ((Database, UUID) throws -> UserItem?)?
    var findByItemIDWithUserHandler: ((Database, UUID) throws -> UserItem?)?
    var saveHandler: ((Database, UserItem) throws -> Void)?
    var deleteHandler: ((Database, UserItem) throws -> Void)?

    func listForUser(userID: UUID, on db: Database) async throws -> [UserItem] {
        try listForUserHandler?(db, userID) ?? []
    }

    func listAllWithItem(on db: Database) async throws -> [UserItem] {
        try listAllWithItemHandler?(db) ?? []
    }

    func listIncoming(for userID: UUID, on db: Database) async throws -> [UserItem] {
        try listIncomingHandler?(db, userID) ?? []
    }

    func find(id: UUID, on db: Database) async throws -> UserItem? {
        try findByIDHandler?(db, id)
    }

    func findWithItem(id: UUID, on db: Database) async throws -> UserItem? {
        try findWithItemHandler?(db, id)
    }

    func findByItemID(itemID: UUID, on db: Database) async throws -> UserItem? {
        try findByItemIDHandler?(db, itemID)
    }

    func findByItemIDWithUser(itemID: UUID, on db: Database) async throws -> UserItem? {
        try findByItemIDWithUserHandler?(db, itemID)
    }

    func save(_ userItem: UserItem, on db: Database) async throws {
        try saveHandler?(db, userItem)
    }

    func delete(_ userItem: UserItem, on db: Database) async throws {
        try deleteHandler?(db, userItem)
    }
}

private struct MockItemLocationRepository: ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? { nil }
    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] { [] }
    func save(_ itemLocation: ItemLocation, on db: Database) async throws {}
}

private struct MockBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool { false }
    func save(_ brokenItem: BrokenItem, on db: Database) async throws {}
}

private struct MockItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] { [] }
    func exists(id: UUID, on db: Database) async throws -> Bool { false }
    func find(id: UUID, on db: Database) async throws -> ItemCategory? { nil }
    func save(_ category: ItemCategory, on db: Database) async throws {}
    func delete(_ category: ItemCategory, on db: Database) async throws {}
}

private struct MockLocationRepository: LocationRepository {
    func list(on db: Database) async throws -> [Location] { [] }
    func find(id: UUID, on db: Database) async throws -> Location? { nil }
    func save(_ location: Location, on db: Database) async throws {}
    func delete(_ location: Location, on db: Database) async throws {}
}

private struct MockItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] { [] }
    func find(id: UUID, on db: Database) async throws -> ItemParameter? { nil }
    func save(_ parameter: ItemParameter, on db: Database) async throws {}
    func delete(_ parameter: ItemParameter, on db: Database) async throws {}
}

private struct MockUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {}
    func deleteByUserID(_ userID: UUID, on db: Database) async throws {}
}

private struct MockItemJournalRepository: ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws {}
    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] { [] }
    func count(itemID: UUID, on db: Database) async throws -> Int { 0 }
}

private struct MockItemJournalService: ItemJournalService {
    func list(itemID: UUID, page: Int?, per: Int?, context: ServiceContext) async throws -> ItemJournalPageResponse {
        ItemJournalPageResponse(messages: [], page: 1, per: 20, total: 0, totalPages: 1, hasNext: false)
    }

    func record(data: ItemJournalRecordData, context: ServiceContext) async throws {}
}
