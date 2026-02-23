import Fluent
import FluentSQL
import Vapor

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

struct AddItemPriceRub: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) ADD COLUMN price_rub NUMERIC(12,2);").run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema)
            .deleteField("price_rub")
            .update()
    }
}

struct ConvertItemPriceRubToNumeric: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw(
            """
            ALTER TABLE \(raw: Item.schema)
            ALTER COLUMN price_rub TYPE NUMERIC(12,2)
            USING price_rub::numeric;
            """
        ).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw(
            """
            ALTER TABLE \(raw: Item.schema)
            ALTER COLUMN price_rub TYPE INTEGER
            USING ROUND(price_rub)::integer;
            """
        ).run()
    }
}

struct AddItemPriceKopecks: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) ADD COLUMN IF NOT EXISTS price_kopecks BIGINT;")
            .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) DROP COLUMN IF EXISTS price_kopecks;").run()
    }
}

struct MigrateItemPriceRubToKopecks: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw(
            """
            UPDATE \(raw: Item.schema)
            SET price_kopecks = ROUND(price_rub * 100)::bigint
            WHERE price_rub IS NOT NULL AND price_kopecks IS NULL;
            """
        ).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.eventLoop.makeSucceededFuture(())
    }
}

struct DropItemPriceRub: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) DROP COLUMN IF EXISTS price_rub;").run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) ADD COLUMN IF NOT EXISTS price_rub NUMERIC(12,2);")
            .run()
    }
}

struct RestoreItemPriceRubFromKopecks: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) ADD COLUMN IF NOT EXISTS price_rub NUMERIC(12,2);")
            .run()
            .flatMap {
                sql.raw(
                    """
                    UPDATE \(raw: Item.schema)
                    SET price_rub = (price_kopecks::numeric / 100.0)
                    WHERE price_kopecks IS NOT NULL AND price_rub IS NULL;
                    """
                ).run()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.eventLoop.makeSucceededFuture(())
    }
}

struct DropItemPriceKopecks: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) DROP COLUMN IF EXISTS price_kopecks;").run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            return database.eventLoop.makeFailedFuture(
                Abort(.internalServerError, reason: "SQL database is required for price migration.")
            )
        }
        return sql.raw("ALTER TABLE \(raw: Item.schema) ADD COLUMN IF NOT EXISTS price_kopecks BIGINT;")
            .run()
    }
}

struct AddItemResponsibleUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema)
            .field(
                "responsible_user_id",
                .uuid,
                .references(User.schema, "id", onDelete: .setNull)
            )
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Item.schema)
            .deleteField("responsible_user_id")
            .update()
    }
}
