import Fluent
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
        let locations = try await Location.query(on: req.db).all()
        try await req.audit(action: "read", entity: "locations", message: "list")
        return locations
    }

    func create(req: Request) async throws -> Location {
        let payload = try req.content.decode(CreateLocationRequest.self)
        let location = Location(
            name: payload.name,
            kind: payload.kind,
            address: payload.address,
            shelf: payload.shelf,
            row: payload.row,
            section: payload.section
        )
        try await location.save(on: req.db)
        try await req.audit(action: "create", entity: "locations", entityID: location.id)
        return location
    }

    func show(req: Request) async throws -> Location {
        let locationID = try req.requireUUID("locationID")
        guard let location = try await Location.find(locationID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await req.audit(action: "read", entity: "locations", entityID: location.id)
        return location
    }

    func update(req: Request) async throws -> Location {
        let payload = try req.content.decode(UpdateLocationRequest.self)
        let locationID = try req.requireUUID("locationID")
        guard let location = try await Location.find(locationID, on: req.db) else {
            throw Abort(.notFound)
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
        try await location.save(on: req.db)
        try await req.audit(action: "update", entity: "locations", entityID: location.id)
        return location
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let locationID = try req.requireUUID("locationID")
        guard let location = try await Location.find(locationID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await location.delete(on: req.db)
        try await req.audit(action: "delete", entity: "locations", entityID: locationID)
        return .noContent
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
