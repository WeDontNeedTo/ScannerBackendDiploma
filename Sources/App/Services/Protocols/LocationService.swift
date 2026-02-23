import Foundation

protocol LocationService {
    func index(context: ServiceContext) async throws -> [Location]
    func create(payload: CreateLocationRequest, context: ServiceContext) async throws -> Location
    func show(locationID: UUID, context: ServiceContext) async throws -> Location
    func update(locationID: UUID, payload: UpdateLocationRequest, context: ServiceContext) async throws -> Location
    func delete(locationID: UUID, context: ServiceContext) async throws
}
