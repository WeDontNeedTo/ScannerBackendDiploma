import Vapor

struct LocationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let locations = routes.grouped("locations")
        locations.get(use: index)
        locations.post(use: create)
        locations.group(":locationID") { location in
            location.get(use: show)
            location.put(use: update)
            location.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [Location] {
        do {
            let locations = try await req.application.services.locationService.index(context: context(req))
            try await req.audit(action: "read", entity: "locations", message: "list")
            return locations
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func create(req: Request) async throws -> Location {
        do {
            let payload = try req.content.decode(CreateLocationRequest.self)
            let location = try await req.application.services.locationService.create(
                payload: payload,
                context: context(req)
            )
            try await req.audit(action: "create", entity: "locations", entityID: location.id)
            return location
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func show(req: Request) async throws -> Location {
        do {
            let locationID = try req.requireUUID("locationID")
            let location = try await req.application.services.locationService.show(
                locationID: locationID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "locations", entityID: location.id)
            return location
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func update(req: Request) async throws -> Location {
        do {
            let payload = try req.content.decode(UpdateLocationRequest.self)
            let locationID = try req.requireUUID("locationID")
            let location = try await req.application.services.locationService.update(
                locationID: locationID,
                payload: payload,
                context: context(req)
            )
            try await req.audit(action: "update", entity: "locations", entityID: location.id)
            return location
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        do {
            let locationID = try req.requireUUID("locationID")
            try await req.application.services.locationService.delete(
                locationID: locationID,
                context: context(req)
            )
            try await req.audit(action: "delete", entity: "locations", entityID: locationID)
            return .noContent
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}

struct CreateLocationRequest: Content {
    let name: String
    let kind: LocationKind
    let address: String?
    let shelf: String?
    let row: String?
    let section: String?
}

struct UpdateLocationRequest: Content {
    let name: String?
    let kind: LocationKind?
    let address: String?
    let shelf: String?
    let row: String?
    let section: String?
}
