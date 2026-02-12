import Fluent
import Vapor

struct ItemCategoryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let categories = routes.grouped("item-categories")
        categories.get(use: index)
        categories.post(use: create)
        categories.group(":categoryID") { category in
            category.get(use: show)
            category.put(use: update)
            category.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [ItemCategory] {
        let categories = try await ItemCategory.query(on: req.db).all()
        try await req.audit(action: "read", entity: "item_categories", message: "list")
        return categories
    }

    func create(req: Request) async throws -> ItemCategory {
        let payload = try req.content.decode(CreateItemCategoryRequest.self)
        let category = ItemCategory(name: payload.name, description: payload.description)
        try await category.save(on: req.db)
        try await req.audit(action: "create", entity: "item_categories", entityID: category.id)
        return category
    }

    func show(req: Request) async throws -> ItemCategory {
        let categoryID = try req.requireUUID("categoryID")
        guard let category = try await ItemCategory.find(categoryID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await req.audit(action: "read", entity: "item_categories", entityID: category.id)
        return category
    }

    func update(req: Request) async throws -> ItemCategory {
        let payload = try req.content.decode(UpdateItemCategoryRequest.self)
        let categoryID = try req.requireUUID("categoryID")
        guard let category = try await ItemCategory.find(categoryID, on: req.db) else {
            throw Abort(.notFound)
        }
        if let name = payload.name {
            category.name = name
        }
        if payload.description != nil {
            category.description = payload.description
        }
        try await category.save(on: req.db)
        try await req.audit(action: "update", entity: "item_categories", entityID: category.id)
        return category
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let categoryID = try req.requireUUID("categoryID")
        guard let category = try await ItemCategory.find(categoryID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await category.delete(on: req.db)
        try await req.audit(action: "delete", entity: "item_categories", entityID: categoryID)
        return .noContent
    }
}

struct CreateItemCategoryRequest: Content {
    let name: String
    let description: String?
}

struct UpdateItemCategoryRequest: Content {
    let name: String?
    let description: String?
}
