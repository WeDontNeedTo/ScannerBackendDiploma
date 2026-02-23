import Fluent
import FluentSQL

struct CreateItemJournalEvent: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemJournalEvent.schema)
            .id()
            .field(
                "item_id",
                .uuid,
                .required,
                .references(Item.schema, "id", onDelete: .cascade)
            )
            .field(
                "actor_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .field("event_type", .string, .required)
            .field("message", .string, .required)
            .field("created_at", .datetime)
            .create()
            .flatMap {
                guard let sql = database as? any SQLDatabase else {
                    return database.eventLoop.makeSucceededFuture(())
                }
                return sql.raw(
                    "CREATE INDEX IF NOT EXISTS item_journal_events_item_id_idx ON item_journal_events (item_id)"
                ).run().flatMap {
                    sql.raw(
                        "CREATE INDEX IF NOT EXISTS item_journal_events_item_id_created_at_idx ON item_journal_events (item_id, created_at)"
                    ).run()
                }
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ItemJournalEvent.schema).delete()
    }
}
