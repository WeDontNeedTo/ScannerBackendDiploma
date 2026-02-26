import Foundation

protocol ItemLocationRequestService {
    func create(data: ItemLocationRequestCreateData, context: ServiceContext) async throws -> ItemLocationRequest
    func incoming(context: ServiceContext) async throws -> [ItemLocationRequest]
    func approve(data: ItemLocationRequestApproveData, context: ServiceContext) async throws -> ItemLocationRequest
}
