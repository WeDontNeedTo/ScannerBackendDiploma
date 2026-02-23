import Fluent
import Foundation
import Vapor

final class Item: Model, Content {
    static let schema = "items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "number")
    var number: String

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "price_rub")
    var priceRub: Decimal?

    @OptionalParent(key: "category_id")
    var category: ItemCategory?

    @OptionalParent(key: "responsible_user_id")
    var responsibleUser: User?

    @Children(for: \.$item)
    var parameters: [ItemParameter]

    @OptionalChild(for: \.$item)
    var grabbedBy: UserItem?

    @OptionalChild(for: \.$item)
    var currentLocation: ItemLocation?

    init() {}

    init(
        id: UUID? = nil,
        number: String,
        name: String,
        description: String? = nil,
        priceRub: Decimal? = nil,
        categoryID: UUID? = nil,
        responsibleUserID: UUID? = nil
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.description = description
        self.priceRub = priceRub
        self.$category.id = categoryID
        self.$responsibleUser.id = responsibleUserID
    }
}
