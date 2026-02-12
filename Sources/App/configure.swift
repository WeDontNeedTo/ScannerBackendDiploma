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

    app.migrations.add(CreateItem())
    app.migrations.add(CreateItemCategory())
    app.migrations.add(AddItemCategoryToItems())
    app.migrations.add(CreateItemParameter())
    app.migrations.add(CreateLocation())
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateUserItem())
    app.migrations.add(RemoveUserItemQuantity())
    app.migrations.add(CreateItemLocation())
    app.migrations.add(AddItemLocationTimestamps())
    app.migrations.add(RemoveItemLocationQuantity())
    app.migrations.add(CreateBrokenItem())
    app.migrations.add(CreateAuditLog())
    app.views.use(.leaf)

    try routes(app)
}
