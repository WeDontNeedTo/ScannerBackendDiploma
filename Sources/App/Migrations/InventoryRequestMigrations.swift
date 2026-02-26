import Fluent
import FluentSQL

struct CreateInventoryRequest: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(InventoryRequest.schema)
            .id()
            .field(
                "requester_user_id",
                .uuid,
                .required,
                .references(User.schema, "id", onDelete: .restrict)
            )
            .field(
                "materially_responsible_user_id",
                .uuid,
                .required,
                .references(User.schema, "id", onDelete: .restrict)
            )
            .field("inventory_date", .date, .required)
            .field("status", .string, .required, .sql(.default("'draft'")))
            .field("submitted_at", .datetime)
            .field("mrp_completed_at", .datetime)
            .field(
                "mrp_completed_by_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field("final_approved_at", .datetime)
            .field(
                "final_approved_by_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
            .flatMap {
                guard let sql = database as? any SQLDatabase else {
                    return database.eventLoop.makeSucceededFuture(())
                }
                return sql.raw(
                    "CREATE INDEX IF NOT EXISTS inventory_requests_mrp_status_idx ON inventory_requests (materially_responsible_user_id, status)"
                ).run().flatMap {
                    sql.raw(
                        "CREATE INDEX IF NOT EXISTS inventory_requests_requester_idx ON inventory_requests (requester_user_id)"
                    ).run()
                }
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(InventoryRequest.schema).delete()
    }
}

struct CreateInventoryRequestItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(InventoryRequestItem.schema)
            .id()
            .field(
                "request_id",
                .uuid,
                .required,
                .references(InventoryRequest.schema, "id", onDelete: .cascade)
            )
            .field(
                "item_id",
                .uuid,
                .required,
                .references(Item.schema, "id", onDelete: .restrict)
            )
            .field("item_number_snapshot", .string, .required)
            .field("item_name_snapshot", .string, .required)
            .field("status", .string, .required, .sql(.default("'pending'")))
            .field("scanned_at", .datetime)
            .field(
                "scanned_by_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field("scanned_item_id", .uuid)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "request_id", "item_id")
            .create()
            .flatMap {
                guard let sql = database as? any SQLDatabase else {
                    return database.eventLoop.makeSucceededFuture(())
                }
                return sql.raw(
                    "CREATE INDEX IF NOT EXISTS inventory_request_items_request_idx ON inventory_request_items (request_id)"
                ).run().flatMap {
                    sql.raw(
                        "CREATE INDEX IF NOT EXISTS inventory_request_items_item_idx ON inventory_request_items (item_id)"
                    ).run()
                }
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(InventoryRequestItem.schema).delete()
    }
}
