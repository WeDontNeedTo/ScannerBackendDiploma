import Fluent
import Vapor

final class ItemCategory: Model, Content {
    static let schema = "item_categories"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @Children(for: \.$category)
    var items: [Item]

    init() {}

    init(id: UUID? = nil, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

struct CreateItemCategory: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemCategory.schema)
            .id()
            .field("name", .string, .required)
            .field("description", .string)
            .unique(on: "name")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemCategory.schema).delete()
    }
}

struct AddItemCategoryToItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema)
            .field(
                "category_id",
                .uuid,
                .references(ItemCategory.schema, "id", onDelete: .setNull)
            )
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema)
            .deleteField("category_id")
            .update()
    }
}
