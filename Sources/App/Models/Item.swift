import Fluent
import Vapor

final class Item: Model, Content {
    static let schema = "items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "number")
    var number: String

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalParent(key: "category_id")
    var category: ItemCategory?

    @Children(for: \.$item)
    var parameters: [ItemParameter]

    @OptionalChild(for: \.$item)
    var grabbedBy: UserItem?

    @OptionalChild(for: \.$item)
    var currentLocation: ItemLocation?

    init() {}

    init(
        id: UUID? = nil,
        number: String,
        name: String,
        description: String? = nil,
        categoryID: UUID? = nil
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.description = description
        self.$category.id = categoryID
    }
}

struct CreateItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema)
            .id()
            .field("number", .string, .required)
            .field("name", .string, .required)
            .field("description", .string)
            .unique(on: "number")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema).delete()
    }
}
