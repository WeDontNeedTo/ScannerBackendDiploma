import Fluent

struct CreateItemLocationRequest: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocationRequest.schema)
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
            .field(
                "requester_user_id",
                .uuid,
                .required,
                .references(User.schema, "id", onDelete: .cascade)
            )
            .field(
                "requested_to_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field(
                "approved_by_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field("status", .string, .required, .sql(.default("'requested'")))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemLocationRequest.schema).delete()
    }
}
