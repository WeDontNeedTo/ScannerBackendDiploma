import Vapor

struct ItemLocationRequestController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let group = routes.grouped("item-location-requests")
        group.get("incoming", use: incoming)
        group.group(":requestID") { request in
            request.post("approve", use: approve)
        }
    }

    func incoming(req: Request) async throws -> [ItemLocationRequest] {
        do {
            let requests = try await req.application.services.itemLocationRequestService.incoming(
                context: context(req)
            )
            try await req.audit(action: "read", entity: "item_location_requests", message: "incoming_requests")
            return requests
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func approve(req: Request) async throws -> ItemLocationRequest {
        do {
            let requestID = try req.requireUUID("requestID")
            let request = try await req.application.services.itemLocationRequestService.approve(
                data: ItemLocationRequestApproveData(requestID: requestID),
                context: context(req)
            )
            try await req.audit(action: "approve", entity: "item_location_requests", entityID: request.id)
            return request
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}
