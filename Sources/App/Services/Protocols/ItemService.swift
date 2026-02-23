import Foundation
import Vapor

protocol ItemService {
    func index(context: ServiceContext) async throws -> [Item]
    func create(data: ItemCreateData, context: ServiceContext) async throws -> Item
    func show(itemID: UUID, context: ServiceContext) async throws -> ItemScanResponse
    func search(data: ItemSearchData, context: ServiceContext) async throws -> [ItemScanResponse]
    func availableFilters(context: ServiceContext) async throws -> ItemAvailableFiltersResponse
    func availableActions(itemID: UUID, context: ServiceContext) async throws -> ItemAvailableActionsResponse
    func setLocation(data: ItemSetLocationData, context: ServiceContext) async throws -> OperationResult<ItemLocation>
    func grab(data: ItemGrabData, context: ServiceContext) async throws -> OperationResult<UserItem>
    func moveToBroken(data: ItemMoveToBrokenData, context: ServiceContext) async throws -> BrokenItem
    func update(data: ItemUpdateData, context: ServiceContext) async throws -> Item
    func delete(itemID: UUID, context: ServiceContext) async throws
}
