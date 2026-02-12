import Fluent
import Vapor

final class AuditLog: Model, Content {
    static let schema = "audit_logs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "action")
    var action: String

    @Field(key: "entity")
    var entity: String

    @OptionalField(key: "entity_id")
    var entityID: UUID?

    @OptionalField(key: "message")
    var message: String?

    @OptionalField(key: "metadata")
    var metadata: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        action: String,
        entity: String,
        entityID: UUID? = nil,
        message: String? = nil,
        metadata: String? = nil
    ) {
        self.id = id
        self.action = action
        self.entity = entity
        self.entityID = entityID
        self.message = message
        self.metadata = metadata
    }
}

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
