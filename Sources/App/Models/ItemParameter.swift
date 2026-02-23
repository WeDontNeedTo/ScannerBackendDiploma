import Fluent
import Vapor

final class ItemParameter: Model, Content {
    static let schema = "item_parameters"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "item_id")
    var item: Item

    @Field(key: "key")
    var key: String

    @Field(key: "value")
    var value: String

    init() {}

    init(id: UUID? = nil, itemID: UUID, key: String, value: String) {
        self.id = id
        self.$item.id = itemID
        self.key = key
        self.value = value
    }
}
