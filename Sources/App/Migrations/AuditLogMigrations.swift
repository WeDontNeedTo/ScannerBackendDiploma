import Fluent

struct CreateAuditLog: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(AuditLog.schema)
            .id()
            .field("action", .string, .required)
            .field("entity", .string, .required)
            .field("entity_id", .uuid)
            .field("message", .string)
            .field("metadata", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(AuditLog.schema).delete()
    }
}
