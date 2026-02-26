import Foundation
import Vapor

struct ItemCategoryItemsCountResponse: Content {
    let categoryID: UUID?
    let categoryName: String
    let itemsCount: Int
}
