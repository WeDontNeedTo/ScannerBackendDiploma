import Fluent
@testable import App
import XCTVapor

final class SettingsUserServiceTests: XCTestCase {
    func testAdminListUsersReturnsAssignedItemsPage() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let admin = makeSettingsUser(role: .admin)
        let target = makeSettingsUser(role: .materiallyResponsiblePerson)
        let assignedItem = makeSettingsItem(responsibleUserID: try target.requireID())

        let userRepo = SettingsTestUserRepository()
        userRepo.countHandler = { _ in 1 }
        userRepo.listHandler = { _, page, per in
            XCTAssertEqual(page, 1)
            XCTAssertEqual(per, 20)
            return [target]
        }

        let itemRepo = SettingsTestItemRepository()
        itemRepo.listByResponsibleUserWithRelationsHandler = { _, userID in
            userID == target.id ? [assignedItem] : []
        }

        let service = DefaultSettingsUserService(
            repositories: makeSettingsRepositoryContainer(userRepository: userRepo, itemRepository: itemRepo)
        )

        let response = try await service.listUsers(
            data: SettingsUsersListData(page: nil, per: nil),
            context: ServiceContext(db: app.db, currentUser: admin)
        )

        XCTAssertEqual(response.users.count, 1)
        XCTAssertEqual(response.users[0].user.id, target.id)
        XCTAssertEqual(response.users[0].assignedItems.count, 1)
        XCTAssertEqual(response.total, 1)
    }

    func testNonAdminListUsersForbidden() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let employee = makeSettingsUser(role: .employee)
        let service = DefaultSettingsUserService(
            repositories: makeSettingsRepositoryContainer(
                userRepository: SettingsTestUserRepository(),
                itemRepository: SettingsTestItemRepository()
            )
        )

        do {
            _ = try await service.listUsers(
                data: SettingsUsersListData(page: 1, per: 20),
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

    func testUpdateRoleToNonMRPBlockedWhenUserHasItems() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let admin = makeSettingsUser(role: .admin)
        let target = makeSettingsUser(role: .materiallyResponsiblePerson)

        let userRepo = SettingsTestUserRepository()
        userRepo.findHandler = { _, _ in target }

        let itemRepo = SettingsTestItemRepository()
        itemRepo.countByResponsibleUserHandler = { _, _ in 2 }

        let service = DefaultSettingsUserService(
            repositories: makeSettingsRepositoryContainer(userRepository: userRepo, itemRepository: itemRepo)
        )

        do {
            _ = try await service.updateRole(
                data: SettingsUserRoleUpdateData(userID: try target.requireID(), role: .employee),
                context: ServiceContext(db: app.db, currentUser: admin)
            )
            XCTFail("Expected conflict")
        } catch let error as DomainError {
            guard case .conflict = error else {
                XCTFail("Expected conflict")
                return
            }
        }
    }

    func testAddItemsToNonMRPTargetFails() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let admin = makeSettingsUser(role: .admin)
        let target = makeSettingsUser(role: .employee)

        let userRepo = SettingsTestUserRepository()
        userRepo.findHandler = { _, _ in target }

        let service = DefaultSettingsUserService(
            repositories: makeSettingsRepositoryContainer(userRepository: userRepo, itemRepository: SettingsTestItemRepository())
        )

        do {
            _ = try await service.addItems(
                data: SettingsUserItemsAddData(userID: try target.requireID(), itemIDs: [UUID()]),
                context: ServiceContext(db: app.db, currentUser: admin)
            )
            XCTFail("Expected conflict")
        } catch let error as DomainError {
            guard case .conflict = error else {
                XCTFail("Expected conflict")
                return
            }
        }
    }

    func testRemoveItemsReassignsToTargetMRP() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let admin = makeSettingsUser(role: .admin)
        let source = makeSettingsUser(role: .materiallyResponsiblePerson)
        let target = makeSettingsUser(role: .materiallyResponsiblePerson)
        let item = makeSettingsItem(responsibleUserID: try source.requireID())
        let itemID = try item.requireID()

        let userRepo = SettingsTestUserRepository()
        userRepo.findHandler = { _, id in
            if id == source.id { return source }
            if id == target.id { return target }
            return nil
        }

        let itemRepo = SettingsTestItemRepository()
        itemRepo.findAllByIDsHandler = { _, ids in ids == [itemID] ? [item] : [] }
        itemRepo.findAllByIDsWithRelationsHandler = { _, ids in ids == [itemID] ? [item] : [] }
        itemRepo.saveAllHandler = { _, _ in }

        let service = DefaultSettingsUserService(
            repositories: makeSettingsRepositoryContainer(userRepository: userRepo, itemRepository: itemRepo)
        )

        let response = try await service.removeItems(
            data: SettingsUserItemsRemoveData(
                userID: try source.requireID(),
                itemIDs: [itemID],
                reassignToUserID: try target.requireID()
            ),
            context: ServiceContext(db: app.db, currentUser: admin)
        )

        XCTAssertEqual(response.userID, target.id)
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(item.$responsibleUser.id, target.id)
    }

    func testSettingsUsersRouteRequiresAuth() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/settings/users") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
}

private func makeSettingsRepositoryContainer(
    userRepository: any UserRepository,
    itemRepository: any ItemRepository
) -> RepositoryContainer {
    RepositoryContainer(
        itemRepository: itemRepository,
        userRepository: userRepository,
        userItemRepository: SettingsTestUserItemRepository(),
        itemLocationRepository: SettingsTestItemLocationRepository(),
        itemLocationRequestRepository: SettingsTestItemLocationRequestRepository(),
        inventoryRequestRepository: SettingsTestInventoryRequestRepository(),
        inventoryRequestItemRepository: SettingsTestInventoryRequestItemRepository(),
        itemJournalRepository: SettingsTestItemJournalRepository(),
        brokenItemRepository: SettingsTestBrokenItemRepository(),
        itemCategoryRepository: SettingsTestItemCategoryRepository(),
        locationRepository: SettingsTestLocationRepository(),
        itemParameterRepository: SettingsTestItemParameterRepository(),
        userTokenRepository: SettingsTestUserTokenRepository()
    )
}

private func makeSettingsUser(role: UserRole) -> User {
    let user = User(
        login: UUID().uuidString,
        passwordHash: "hash",
        fullName: "Settings User",
        age: 30,
        position: "Engineer",
        role: role
    )
    user.id = UUID()
    return user
}

private func makeSettingsItem(responsibleUserID: UUID) -> Item {
    let item = Item(number: "SKU-\(UUID().uuidString)", name: "Item", responsibleUserID: responsibleUserID)
    item.id = UUID()
    return item
}

private final class SettingsTestUserRepository: UserRepository {
    var findHandler: ((Database, UUID) throws -> User?)?
    var listHandler: ((Database, Int, Int) throws -> [User])?
    var countHandler: ((Database) throws -> Int)?

    func find(id: UUID, on db: Database) async throws -> User? { try findHandler?(db, id) }
    func findByLogin(_ login: String, on db: Database) async throws -> User? { nil }
    func list(page: Int, per: Int, on db: Database) async throws -> [User] {
        try listHandler?(db, page, per) ?? []
    }
    func count(on db: Database) async throws -> Int { try countHandler?(db) ?? 0 }
    func listMateriallyResponsible(on db: Database) async throws -> [User] { [] }
    func save(_ user: User, on db: Database) async throws {}
}

private final class SettingsTestItemRepository: ItemRepository {
    var countByResponsibleUserHandler: ((Database, UUID) throws -> Int)?
    var listByResponsibleUserWithRelationsHandler: ((Database, UUID) throws -> [Item])?
    var findAllByIDsHandler: ((Database, [UUID]) throws -> [Item])?
    var findAllByIDsWithRelationsHandler: ((Database, [UUID]) throws -> [Item])?
    var saveAllHandler: ((Database, [Item]) throws -> Void)?

    func listWithRelations(on db: Database) async throws -> [Item] { [] }
    func findWithRelations(id: UUID, on db: Database) async throws -> Item? { nil }
    func findWithRelations(number: String, on db: Database) async throws -> Item? { nil }
    func search(with data: ItemSearchData, on db: Database) async throws -> [Item] { [] }
    func dashboardBalanceStats(responsibleUserID: UUID, on db: Database) async throws -> DashboardBalanceStats {
        DashboardBalanceStats(ownedItemsCount: 0, totalBalanceRub: .zero, items: [])
    }
    func countByResponsibleUser(responsibleUserID: UUID, on db: Database) async throws -> Int {
        try countByResponsibleUserHandler?(db, responsibleUserID) ?? 0
    }
    func listByResponsibleUserWithRelations(responsibleUserID: UUID, on db: Database) async throws -> [Item] {
        try listByResponsibleUserWithRelationsHandler?(db, responsibleUserID) ?? []
    }
    func findAllByIDs(_ ids: [UUID], on db: Database) async throws -> [Item] {
        try findAllByIDsHandler?(db, ids) ?? []
    }
    func findAllByIDsWithRelations(_ ids: [UUID], on db: Database) async throws -> [Item] {
        try findAllByIDsWithRelationsHandler?(db, ids) ?? []
    }
    func saveAll(_ items: [Item], on db: Database) async throws {
        try saveAllHandler?(db, items)
    }
    func find(id: UUID, on db: Database) async throws -> Item? { nil }
    func save(_ item: Item, on db: Database) async throws {}
    func delete(_ item: Item, on db: Database) async throws {}
}

private struct SettingsTestUserItemRepository: UserItemRepository {
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

private struct SettingsTestItemLocationRepository: ItemLocationRepository {
    func find(itemID: UUID, locationID: UUID, on db: Database) async throws -> ItemLocation? { nil }
    func listByItemWithLocation(itemID: UUID, on db: Database) async throws -> [ItemLocation] { [] }
    func save(_ itemLocation: ItemLocation, on db: Database) async throws {}
}

private struct SettingsTestItemLocationRequestRepository: ItemLocationRequestRepository {
    func find(id: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func findRequested(itemID: UUID, locationID: UUID, requesterUserID: UUID, on db: Database) async throws -> ItemLocationRequest? { nil }
    func listIncoming(for userID: UUID, on db: Database) async throws -> [ItemLocationRequest] { [] }
    func save(_ request: ItemLocationRequest, on db: Database) async throws {}
}

private struct SettingsTestInventoryRequestRepository: InventoryRequestRepository {
    func create(_ request: InventoryRequest, on db: Database) async throws {}
    func find(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func findWithItems(id: UUID, on db: Database) async throws -> InventoryRequest? { nil }
    func listIncoming(materiallyResponsibleUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func listMine(requesterUserID: UUID, on db: Database) async throws -> [InventoryRequest] { [] }
    func save(_ request: InventoryRequest, on db: Database) async throws {}
    func findActiveConflictingItemIDs(itemIDs: [UUID], excludingRequestID: UUID?, on db: Database) async throws -> Set<UUID> { [] }
}

private struct SettingsTestInventoryRequestItemRepository: InventoryRequestItemRepository {
    func create(_ item: InventoryRequestItem, on db: Database) async throws {}
    func find(requestID: UUID, itemID: UUID, on db: Database) async throws -> InventoryRequestItem? { nil }
    func listByRequestID(requestID: UUID, on db: Database) async throws -> [InventoryRequestItem] { [] }
    func deleteByRequestID(requestID: UUID, on db: Database) async throws {}
    func save(_ item: InventoryRequestItem, on db: Database) async throws {}
}

private struct SettingsTestItemJournalRepository: ItemJournalRepository {
    func create(_ event: ItemJournalEvent, on db: Database) async throws {}
    func list(itemID: UUID, offset: Int, limit: Int, on db: Database) async throws -> [ItemJournalEvent] { [] }
    func count(itemID: UUID, on db: Database) async throws -> Int { 0 }
}

private struct SettingsTestBrokenItemRepository: BrokenItemRepository {
    func hasPositiveQuantity(itemID: UUID, on db: Database) async throws -> Bool { false }
    func listWithItem(on db: Database) async throws -> [BrokenItem] { [] }
    func listWithItem(responsibleUserID: UUID, on db: Database) async throws -> [BrokenItem] { [] }
    func save(_ brokenItem: BrokenItem, on db: Database) async throws {}
}

private struct SettingsTestItemCategoryRepository: ItemCategoryRepository {
    func list(on db: Database) async throws -> [ItemCategory] { [] }
    func listWithItemCounts(on db: Database) async throws -> [ItemCategoryItemsCount] { [] }
    func exists(id: UUID, on db: Database) async throws -> Bool { false }
    func find(id: UUID, on db: Database) async throws -> ItemCategory? { nil }
    func save(_ category: ItemCategory, on db: Database) async throws {}
    func delete(_ category: ItemCategory, on db: Database) async throws {}
}

private struct SettingsTestLocationRepository: LocationRepository {
    func list(on db: Database) async throws -> [Location] { [] }
    func find(id: UUID, on db: Database) async throws -> Location? { nil }
    func save(_ location: Location, on db: Database) async throws {}
    func delete(_ location: Location, on db: Database) async throws {}
}

private struct SettingsTestItemParameterRepository: ItemParameterRepository {
    func list(on db: Database) async throws -> [ItemParameter] { [] }
    func find(id: UUID, on db: Database) async throws -> ItemParameter? { nil }
    func save(_ parameter: ItemParameter, on db: Database) async throws {}
    func delete(_ parameter: ItemParameter, on db: Database) async throws {}
}

private struct SettingsTestUserTokenRepository: UserTokenRepository {
    func save(_ token: UserToken, on db: Database) async throws {}
    func deleteByUserID(_ userID: UUID, on db: Database) async throws {}
}
