import Fluent

struct CreateItemParameter: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemParameter.schema)
            .id()
            .field("item_id", .uuid, .required, .references(Item.schema, "id", onDelete: .cascade))
            .field("key", .string, .required)
            .field("value", .string, .required)
            .unique(on: "item_id", "key")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemParameter.schema).delete()
    }
}
