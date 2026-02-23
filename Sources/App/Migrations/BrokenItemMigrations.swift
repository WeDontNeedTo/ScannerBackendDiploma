import Fluent

struct CreateBrokenItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(BrokenItem.schema)
            .id()
            .field(
                "item_id",
                .uuid,
                .required,
                .references(Item.schema, "id", onDelete: .restrict)
            )
            .field(
                "location_id",
                .uuid,
                .required,
                .references(Location.schema, "id", onDelete: .restrict)
            )
            .field("quantity", .int, .required)
            .field("reported_at", .datetime, .required)
            .field("reason", .string)
            .field("notes", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(BrokenItem.schema).delete()
    }
}
