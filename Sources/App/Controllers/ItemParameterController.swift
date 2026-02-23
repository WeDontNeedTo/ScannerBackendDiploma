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
        do {
            let parameters = try await req.application.services.itemParameterService.index(context: context(req))
            try await req.audit(action: "read", entity: "item_parameters", message: "list")
            return parameters
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func create(req: Request) async throws -> ItemParameter {
        do {
            let payload = try req.content.decode(CreateItemParameterRequest.self)
            let parameter = try await req.application.services.itemParameterService.create(
                payload: payload,
                context: context(req)
            )
            try await req.audit(action: "create", entity: "item_parameters", entityID: parameter.id)
            return parameter
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func show(req: Request) async throws -> ItemParameter {
        do {
            let parameterID = try req.requireUUID("parameterID")
            let parameter = try await req.application.services.itemParameterService.show(
                parameterID: parameterID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "item_parameters", entityID: parameter.id)
            return parameter
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func update(req: Request) async throws -> ItemParameter {
        do {
            let payload = try req.content.decode(UpdateItemParameterRequest.self)
            let parameterID = try req.requireUUID("parameterID")
            let parameter = try await req.application.services.itemParameterService.update(
                parameterID: parameterID,
                payload: payload,
                context: context(req)
            )
            try await req.audit(action: "update", entity: "item_parameters", entityID: parameter.id)
            return parameter
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        do {
            let parameterID = try req.requireUUID("parameterID")
            try await req.application.services.itemParameterService.delete(
                parameterID: parameterID,
                context: context(req)
            )
            try await req.audit(action: "delete", entity: "item_parameters", entityID: parameterID)
            return .noContent
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
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
