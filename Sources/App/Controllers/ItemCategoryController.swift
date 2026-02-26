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
        categories.get("counts", use: counts)
    }

    func index(req: Request) async throws -> [ItemCategory] {
        do {
            let categories = try await req.application.services.itemCategoryService.index(context: context(req))
            try await req.audit(action: "read", entity: "item_categories", message: "list")
            return categories
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func create(req: Request) async throws -> ItemCategory {
        do {
            let payload = try req.content.decode(CreateItemCategoryRequest.self)
            let category = try await req.application.services.itemCategoryService.create(
                payload: payload,
                context: context(req)
            )
            try await req.audit(action: "create", entity: "item_categories", entityID: category.id)
            return category
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func counts(req: Request) async throws -> [ItemCategoryItemsCountResponse] {
        do {
            let counts = try await req.application.services.itemCategoryService.counts(context: context(req))
            try await req.audit(action: "read", entity: "item_categories", message: "counts")
            return counts
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func show(req: Request) async throws -> ItemCategory {
        do {
            let categoryID = try req.requireUUID("categoryID")
            let category = try await req.application.services.itemCategoryService.show(
                categoryID: categoryID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "item_categories", entityID: category.id)
            return category
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func update(req: Request) async throws -> ItemCategory {
        do {
            let payload = try req.content.decode(UpdateItemCategoryRequest.self)
            let categoryID = try req.requireUUID("categoryID")
            let category = try await req.application.services.itemCategoryService.update(
                categoryID: categoryID,
                payload: payload,
                context: context(req)
            )
            try await req.audit(action: "update", entity: "item_categories", entityID: category.id)
            return category
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        do {
            let categoryID = try req.requireUUID("categoryID")
            try await req.application.services.itemCategoryService.delete(
                categoryID: categoryID,
                context: context(req)
            )
            try await req.audit(action: "delete", entity: "item_categories", entityID: categoryID)
            return .noContent
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
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
