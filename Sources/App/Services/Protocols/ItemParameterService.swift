import Foundation

protocol ItemParameterService {
    func index(context: ServiceContext) async throws -> [ItemParameter]
    func create(payload: CreateItemParameterRequest, context: ServiceContext) async throws -> ItemParameter
    func show(parameterID: UUID, context: ServiceContext) async throws -> ItemParameter
    func update(parameterID: UUID, payload: UpdateItemParameterRequest, context: ServiceContext) async throws -> ItemParameter
    func delete(parameterID: UUID, context: ServiceContext) async throws
}
