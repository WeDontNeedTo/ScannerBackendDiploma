import Fluent
import FluentSQL
import Vapor

struct CreateUserItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .id()
            .field(
                "user_id",
                .uuid,
                .required,
                .references(User.schema, "id", onDelete: .cascade)
            )
            .field(
                "item_id",
                .uuid,
                .required,
                .references(Item.schema, "id", onDelete: .restrict)
            )
            .field("grabbed_at", .datetime)
            .unique(on: "item_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema).delete()
    }
}

struct RemoveUserItemQuantity: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .deleteField("quantity")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .field("quantity", .int, .required)
            .update()
    }
}

struct AddUserItemRequestWorkflow: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .field("status", .string, .required, .sql(.default("'approved'")))
            .field(
                "approved_by_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field(
                "requested_to_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserItem.schema)
            .deleteField("requested_to_user_id")
            .deleteField("approved_by_user_id")
            .deleteField("status")
            .update()
    }
}

struct AddUserItemRequestedToUserField: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(
                    .internalServerError,
                    reason: "SQL database is required for requested_to_user migration."
                )
            )
        }
        return sql.raw(
            """
            ALTER TABLE \(unsafeRaw: UserItem.schema)
            ADD COLUMN IF NOT EXISTS requested_to_user_id UUID
            REFERENCES \(unsafeRaw: User.schema)(id)
            ON DELETE SET NULL;
            """
        ).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(
                    .internalServerError,
                    reason: "SQL database is required for requested_to_user migration."
                )
            )
        }
        return sql.raw(
            """
            ALTER TABLE \(unsafeRaw: UserItem.schema)
            DROP COLUMN IF EXISTS requested_to_user_id;
            """
        ).run()
    }
}
