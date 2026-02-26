import Foundation

protocol InventoryRequestService {
    func createDraft(data: InventoryRequestCreateDraftData, context: ServiceContext) async throws -> InventoryRequestResponse
    func setItems(data: InventoryRequestSetItemsData, context: ServiceContext) async throws -> InventoryRequestResponse
    func submit(data: InventoryRequestSubmitData, context: ServiceContext) async throws -> InventoryRequestResponse
    func incoming(context: ServiceContext) async throws -> [InventoryRequestResponse]
    func mine(context: ServiceContext) async throws -> [InventoryRequestResponse]
    func show(requestID: UUID, context: ServiceContext) async throws -> InventoryRequestResponse
    func scanItem(data: InventoryRequestScanData, context: ServiceContext) async throws -> InventoryRequestResponse
    func mrpComplete(data: InventoryRequestMRPCompleteData, context: ServiceContext) async throws -> InventoryRequestResponse
    func finalApprove(data: InventoryRequestFinalApproveData, context: ServiceContext) async throws -> InventoryRequestResponse
}
