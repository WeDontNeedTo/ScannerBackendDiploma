import Foundation

struct DefaultItemParameterService: ItemParameterService {
    private let itemParameterRepository: any ItemParameterRepository

    init(repositories: RepositoryContainer) {
        self.itemParameterRepository = repositories.itemParameterRepository
    }

    func index(context: ServiceContext) async throws -> [ItemParameter] {
        try await itemParameterRepository.list(on: context.db)
    }

    func create(payload: CreateItemParameterRequest, context: ServiceContext) async throws -> ItemParameter {
        let parameter = ItemParameter(itemID: payload.itemID, key: payload.key, value: payload.value)
        try await itemParameterRepository.save(parameter, on: context.db)
        return parameter
    }

    func show(parameterID: UUID, context: ServiceContext) async throws -> ItemParameter {
        guard let parameter = try await itemParameterRepository.find(id: parameterID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        return parameter
    }

    func update(parameterID: UUID, payload: UpdateItemParameterRequest, context: ServiceContext) async throws -> ItemParameter {
        guard let parameter = try await itemParameterRepository.find(id: parameterID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if let itemID = payload.itemID {
            parameter.$item.id = itemID
        }
        if let key = payload.key {
            parameter.key = key
        }
        if let value = payload.value {
            parameter.value = value
        }

        try await itemParameterRepository.save(parameter, on: context.db)
        return parameter
    }

    func delete(parameterID: UUID, context: ServiceContext) async throws {
        guard let parameter = try await itemParameterRepository.find(id: parameterID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        try await itemParameterRepository.delete(parameter, on: context.db)
    }
}
