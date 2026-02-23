import Foundation

struct DefaultItemCategoryService: ItemCategoryService {
    private let itemCategoryRepository: any ItemCategoryRepository

    init(repositories: RepositoryContainer) {
        self.itemCategoryRepository = repositories.itemCategoryRepository
    }

    func index(context: ServiceContext) async throws -> [ItemCategory] {
        try await itemCategoryRepository.list(on: context.db)
    }

    func create(payload: CreateItemCategoryRequest, context: ServiceContext) async throws -> ItemCategory {
        let category = ItemCategory(name: payload.name, description: payload.description)
        try await itemCategoryRepository.save(category, on: context.db)
        return category
    }

    func show(categoryID: UUID, context: ServiceContext) async throws -> ItemCategory {
        guard let category = try await itemCategoryRepository.find(id: categoryID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        return category
    }

    func update(categoryID: UUID, payload: UpdateItemCategoryRequest, context: ServiceContext) async throws -> ItemCategory {
        guard let category = try await itemCategoryRepository.find(id: categoryID, on: context.db) else {
            throw DomainError.notFound(nil)
        }

        if let name = payload.name {
            category.name = name
        }
        if payload.description != nil {
            category.description = payload.description
        }

        try await itemCategoryRepository.save(category, on: context.db)
        return category
    }

    func delete(categoryID: UUID, context: ServiceContext) async throws {
        guard let category = try await itemCategoryRepository.find(id: categoryID, on: context.db) else {
            throw DomainError.notFound(nil)
        }
        try await itemCategoryRepository.delete(category, on: context.db)
    }
}
