import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

public func configure(_ app: Application) throws {
    if let databaseURL = Environment.get("DATABASE_URL"),
       var postgresConfig = try? SQLPostgresConfiguration(url: databaseURL) {
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
    } else {
        app.databases.use(
            .postgres(
                configuration: .init(
                    hostname: "localhost",
                    port: 5433,
                    username: "postgres",
                    password: "root",
                    database: "vapor",
                    tls: .disable
                )
            ),
            as: .psql
        )
    }

    app.repositories = RepositoryContainer(
        itemRepository: FluentItemRepository(),
        userRepository: FluentUserRepository(),
        userItemRepository: FluentUserItemRepository(),
        itemLocationRepository: FluentItemLocationRepository(),
        itemLocationRequestRepository: FluentItemLocationRequestRepository(),
        inventoryRequestRepository: FluentInventoryRequestRepository(),
        inventoryRequestItemRepository: FluentInventoryRequestItemRepository(),
        itemJournalRepository: FluentItemJournalRepository(),
        brokenItemRepository: FluentBrokenItemRepository(),
        itemCategoryRepository: FluentItemCategoryRepository(),
        locationRepository: FluentLocationRepository(),
        itemParameterRepository: FluentItemParameterRepository(),
        userTokenRepository: FluentUserTokenRepository()
    )

    let itemJournalService = DefaultItemJournalService(repositories: app.repositories)
    app.services = ServiceContainer(
        dashboardService: DefaultDashboardService(repositories: app.repositories),
        itemService: DefaultItemService(repositories: app.repositories, itemJournalService: itemJournalService),
        itemLocationRequestService: DefaultItemLocationRequestService(
            repositories: app.repositories,
            itemJournalService: itemJournalService
        ),
        inventoryRequestService: DefaultInventoryRequestService(repositories: app.repositories),
        settingsUserService: DefaultSettingsUserService(repositories: app.repositories),
        itemJournalService: itemJournalService,
        userItemService: DefaultUserItemService(
            repositories: app.repositories,
            itemJournalService: itemJournalService
        ),
        authService: DefaultAuthService(repositories: app.repositories),
        userService: DefaultUserService(repositories: app.repositories),
        locationService: DefaultLocationService(repositories: app.repositories),
        itemCategoryService: DefaultItemCategoryService(repositories: app.repositories),
        itemParameterService: DefaultItemParameterService(repositories: app.repositories)
    )

    app.migrations.add(CreateItem())
    app.migrations.add(AddItemPriceRub())
    app.migrations.add(ConvertItemPriceRubToNumeric())
    app.migrations.add(AddItemPriceKopecks())
    app.migrations.add(MigrateItemPriceRubToKopecks())
    app.migrations.add(DropItemPriceRub())
    app.migrations.add(RestoreItemPriceRubFromKopecks())
    app.migrations.add(DropItemPriceKopecks())
    app.migrations.add(CreateItemCategory())
    app.migrations.add(AddItemCategoryToItems())
    app.migrations.add(CreateItemParameter())
    app.migrations.add(CreateLocation())
    app.migrations.add(CreateUser())
    app.migrations.add(AddItemResponsibleUser())
    app.migrations.add(AddUserRoleField())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateUserItem())
    app.migrations.add(RemoveUserItemQuantity())
    app.migrations.add(AddUserItemRequestWorkflow())
    app.migrations.add(AddUserItemRequestedToUserField())
    app.migrations.add(CreateItemLocation())
    app.migrations.add(AddItemLocationTimestamps())
    app.migrations.add(RemoveItemLocationQuantity())
    app.migrations.add(CreateItemLocationRequest())
    app.migrations.add(CreateInventoryRequest())
    app.migrations.add(CreateInventoryRequestItem())
    app.migrations.add(CreateBrokenItem())
    app.migrations.add(CreateAuditLog())
    app.migrations.add(CreateItemJournalEvent())
    app.views.use(.leaf)

    try routes(app)
}
