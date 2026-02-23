import Fluent

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
