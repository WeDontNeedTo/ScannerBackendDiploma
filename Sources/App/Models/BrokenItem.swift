import Fluent
import Vapor

final class BrokenItem: Model, Content {
    static let schema = "broken_items"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "item_id")
    var item: Item

    @Parent(key: "location_id")
    var location: Location

    @Field(key: "quantity")
    var quantity: Int

    @Field(key: "reported_at")
    var reportedAt: Date

    @OptionalField(key: "reason")
    var reason: String?

    @OptionalField(key: "notes")
    var notes: String?

    init() {}

    init(
        id: UUID? = nil,
        itemID: UUID,
        locationID: UUID,
        quantity: Int,
        reportedAt: Date,
        reason: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.$item.id = itemID
        self.$location.id = locationID
        self.quantity = quantity
        self.reportedAt = reportedAt
        self.reason = reason
        self.notes = notes
    }
}

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
