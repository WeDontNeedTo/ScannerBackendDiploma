import Fluent
import Vapor

struct ItemParameterController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let parameters = routes.grouped("item-parameters")
        parameters.get(use: index)
        parameters.post(use: create)
        parameters.group(":parameterID") { parameter in
            parameter.get(use: show)
            parameter.put(use: update)
            parameter.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [ItemParameter] {
        let parameters = try await ItemParameter.query(on: req.db).all()
        try await req.audit(action: "read", entity: "item_parameters", message: "list")
        return parameters
    }

    func create(req: Request) async throws -> ItemParameter {
        let payload = try req.content.decode(CreateItemParameterRequest.self)
        let parameter = ItemParameter(itemID: payload.itemID, key: payload.key, value: payload.value)
        try await parameter.save(on: req.db)
        try await req.audit(action: "create", entity: "item_parameters", entityID: parameter.id)
        return parameter
    }

    func show(req: Request) async throws -> ItemParameter {
        let parameterID = try req.requireUUID("parameterID")
        guard let parameter = try await ItemParameter.find(parameterID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await req.audit(action: "read", entity: "item_parameters", entityID: parameter.id)
        return parameter
    }

    func update(req: Request) async throws -> ItemParameter {
        let payload = try req.content.decode(UpdateItemParameterRequest.self)
        let parameterID = try req.requireUUID("parameterID")
        guard let parameter = try await ItemParameter.find(parameterID, on: req.db) else {
            throw Abort(.notFound)
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
        try await parameter.save(on: req.db)
        try await req.audit(action: "update", entity: "item_parameters", entityID: parameter.id)
        return parameter
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let parameterID = try req.requireUUID("parameterID")
        guard let parameter = try await ItemParameter.find(parameterID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await parameter.delete(on: req.db)
        try await req.audit(action: "delete", entity: "item_parameters", entityID: parameterID)
        return .noContent
    }
}

struct CreateItemParameterRequest: Content {
    let itemID: UUID
    let key: String
    let value: String
}

struct UpdateItemParameterRequest: Content {
    let itemID: UUID?
    let key: String?
    let value: String?
}
