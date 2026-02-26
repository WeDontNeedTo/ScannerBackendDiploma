import Vapor

struct InventoryRequestController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let inventory = routes.grouped("inventory-requests")
        inventory.post("drafts", use: createDraft)
        inventory.get("incoming", use: incoming)
        inventory.get("mine", use: mine)
        inventory.group(":requestID") { request in
            request.get(use: show)
            request.put("items", use: setItems)
            request.post("submit", use: submit)
            request.post("mrp-complete", use: mrpComplete)
            request.post("final-approve", use: finalApprove)
            request.group("items", ":itemID") { item in
                item.post("scan", use: scanItem)
            }
        }
    }

    func createDraft(req: Request) async throws -> InventoryRequestResponse {
        do {
            let payload = try req.content.decode(CreateInventoryRequestDraftPayload.self)
            let response = try await req.application.services.inventoryRequestService.createDraft(
                data: InventoryRequestCreateDraftData(
                    materiallyResponsibleUserID: payload.materiallyResponsibleUserID,
                    inventoryDate: payload.inventoryDate
                ),
                context: context(req)
            )
            try await req.audit(action: "create", entity: "inventory_requests", entityID: response.id)
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func setItems(req: Request) async throws -> InventoryRequestResponse {
        do {
            let requestID = try req.requireUUID("requestID")
            let payload = try req.content.decode(UpdateInventoryRequestItemsPayload.self)
            let response = try await req.application.services.inventoryRequestService.setItems(
                data: InventoryRequestSetItemsData(requestID: requestID, itemIDs: payload.itemIDs),
                context: context(req)
            )
            try await req.audit(action: "update", entity: "inventory_requests", entityID: response.id, message: "set_items")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func submit(req: Request) async throws -> InventoryRequestResponse {
        do {
            let requestID = try req.requireUUID("requestID")
            let response = try await req.application.services.inventoryRequestService.submit(
                data: InventoryRequestSubmitData(requestID: requestID),
                context: context(req)
            )
            try await req.audit(action: "submit", entity: "inventory_requests", entityID: response.id)
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func incoming(req: Request) async throws -> [InventoryRequestResponse] {
        do {
            let responses = try await req.application.services.inventoryRequestService.incoming(
                context: context(req)
            )
            try await req.audit(action: "read", entity: "inventory_requests", message: "incoming")
            return responses
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func mine(req: Request) async throws -> [InventoryRequestResponse] {
        do {
            let responses = try await req.application.services.inventoryRequestService.mine(context: context(req))
            try await req.audit(action: "read", entity: "inventory_requests", message: "mine")
            return responses
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func show(req: Request) async throws -> InventoryRequestResponse {
        do {
            let requestID = try req.requireUUID("requestID")
            let response = try await req.application.services.inventoryRequestService.show(
                requestID: requestID,
                context: context(req)
            )
            try await req.audit(action: "read", entity: "inventory_requests", entityID: response.id)
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func scanItem(req: Request) async throws -> InventoryRequestResponse {
        do {
            let requestID = try req.requireUUID("requestID")
            let itemID = try req.requireUUID("itemID")
            let payload = try req.content.decode(InventoryScanPayload.self)
            let response = try await req.application.services.inventoryRequestService.scanItem(
                data: InventoryRequestScanData(
                    requestID: requestID,
                    itemID: itemID,
                    scannedItemID: payload.scannedItemID
                ),
                context: context(req)
            )
            try await req.audit(action: "scan", entity: "inventory_request_items", entityID: itemID)
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func mrpComplete(req: Request) async throws -> InventoryRequestResponse {
        do {
            let requestID = try req.requireUUID("requestID")
            let payload = try req.content.decode(InventoryMRPCompletePayload.self)
            let response = try await req.application.services.inventoryRequestService.mrpComplete(
                data: InventoryRequestMRPCompleteData(requestID: requestID, outcome: payload.outcome),
                context: context(req)
            )
            try await req.audit(action: "complete", entity: "inventory_requests", entityID: response.id, message: payload.outcome.rawValue)
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func finalApprove(req: Request) async throws -> InventoryRequestResponse {
        do {
            let requestID = try req.requireUUID("requestID")
            let response = try await req.application.services.inventoryRequestService.finalApprove(
                data: InventoryRequestFinalApproveData(requestID: requestID),
                context: context(req)
            )
            try await req.audit(action: "approve", entity: "inventory_requests", entityID: response.id, message: "final")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}
