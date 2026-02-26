import Foundation

protocol ItemCategoryService {
    func index(context: ServiceContext) async throws -> [ItemCategory]
    func counts(context: ServiceContext) async throws -> [ItemCategoryItemsCountResponse]
    func create(payload: CreateItemCategoryRequest, context: ServiceContext) async throws -> ItemCategory
    func show(categoryID: UUID, context: ServiceContext) async throws -> ItemCategory
    func update(categoryID: UUID, payload: UpdateItemCategoryRequest, context: ServiceContext) async throws -> ItemCategory
    func delete(categoryID: UUID, context: ServiceContext) async throws
}
