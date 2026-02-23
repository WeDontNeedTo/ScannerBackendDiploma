import Foundation

protocol UserItemService {
    func index(context: ServiceContext) async throws -> [UserItem]
    func incoming(context: ServiceContext) async throws -> [UserItem]
    func create(data: UserItemCreateData, context: ServiceContext) async throws -> OperationResult<UserItem>
    func show(userItemID: UUID, context: ServiceContext) async throws -> UserItem
    func approve(data: UserItemApproveData, context: ServiceContext) async throws -> UserItem
    func update(data: UserItemUpdateData, context: ServiceContext) async throws -> UserItem
    func delete(data: UserItemDeleteData, context: ServiceContext) async throws
    func `return`(data: UserItemReturnData, context: ServiceContext) async throws -> UUID?
    func transferRequest(data: UserItemTransferData, context: ServiceContext) async throws -> UserItem
    func transfer(data: UserItemTransferData, context: ServiceContext) async throws -> UserItem
}
