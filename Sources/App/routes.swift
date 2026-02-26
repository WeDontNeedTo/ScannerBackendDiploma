import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        "Vapor API is running"
    }

    try app.register(collection: AdminController())
    try app.register(collection: AuthController())
    try app.register(collection: SwaggerController())

    let tokenProtected = app.grouped(
        UserToken.authenticator(),
        User.guardMiddleware()
    )
    try tokenProtected.register(collection: DashboardController())
    try tokenProtected.register(collection: ItemController())
    try tokenProtected.register(collection: ItemLocationRequestController())
    try tokenProtected.register(collection: InventoryRequestController())
    try tokenProtected.register(collection: SettingsUserController())
    try tokenProtected.register(collection: ItemCategoryController())
    try tokenProtected.register(collection: ItemParameterController())
    try tokenProtected.register(collection: LocationController())
    try tokenProtected.register(collection: UserItemController())
    try tokenProtected.register(collection: UserController())


}
