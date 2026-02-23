import Fluent
import Vapor

final class ItemLocation: Model, Content {
    static let schema = "item_locations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "item_id")
    var item: Item

    @Parent(key: "location_id")
    var location: Location

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, itemID: UUID, locationID: UUID) {
        self.id = id
        self.$item.id = itemID
        self.$location.id = locationID
    }
}
