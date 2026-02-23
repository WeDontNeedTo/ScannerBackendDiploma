import Fluent

struct CreateItemLocation: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocation.schema)
            .id()
            .field(
                "item_id",
                .uuid,
                .required,
                .references(Item.schema, "id", onDelete: .cascade)
            )
            .field(
                "location_id",
                .uuid,
                .required,
                .references(Location.schema, "id", onDelete: .cascade)
            )
            .field("quantity", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "item_id", "location_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocation.schema).delete()
    }
}

struct RemoveItemLocationQuantity: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocation.schema)
            .deleteField("quantity")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocation.schema)
            .field("quantity", .int, .required)
            .update()
    }
}

struct AddItemLocationTimestamps: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocation.schema)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocation.schema)
            .deleteField("created_at")
            .deleteField("updated_at")
            .update()
    }
}
