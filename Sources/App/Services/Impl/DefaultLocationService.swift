import Foundation

struct DefaultLocationService: LocationService {
    private let locationRepository: any LocationRepository

    init(repositories: RepositoryContainer) {
        self.locationRepository = repositories.locationRepository
    }

    func index(context: ServiceContext) async throws -> [Location] {
        try await locationRepository.list(on: context.db)
    }

    func create(payload: CreateLocationRequest, context: ServiceContext) async throws -> Location {
        let location = Location(
            name: payload.name,
            kind: payload.kind,
            address: payload.address,
            shelf: payload.shelf,
            row: payload.row,
            section: payload.section
        )
        try await locationRepository.save(location, on: context.db)
        return location
    }

    func show(locationID: UUID, context: ServiceContext) async throws -> Location {
        guard let location = try await locationRepository.find(id: locationID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        return location
    }

    func update(locationID: UUID, payload: UpdateLocationRequest, context: ServiceContext) async throws -> Location {
        guard let location = try await locationRepository.find(id: locationID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if let name = payload.name {
            location.name = name
        }
        if let kind = payload.kind {
            location.kind = kind
        }
        if payload.address != nil {
            location.address = payload.address
        }
        if payload.shelf != nil {
            location.shelf = payload.shelf
        }
        if payload.row != nil {
            location.row = payload.row
        }
        if payload.section != nil {
            location.section = payload.section
        }

        try await locationRepository.save(location, on: context.db)
        return location
    }

    func delete(locationID: UUID, context: ServiceContext) async throws {
        guard let location = try await locationRepository.find(id: locationID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        try await locationRepository.delete(location, on: context.db)
    }
}
