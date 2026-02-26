import Vapor

struct SettingsUserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let settingsUsers = routes.grouped("settings", "users")
        settingsUsers.get(use: listUsers)
        settingsUsers.put(":userID", "role", use: updateRole)
        settingsUsers.post(":userID", "items", "add", use: addItems)
        settingsUsers.post(":userID", "items", "remove", use: removeItems)
    }

    func listUsers(req: Request) async throws -> SettingsUsersPageResponse {
        do {
            let query = try req.query.decode(SettingsUsersQuery.self)
            let response = try await req.application.services.settingsUserService.listUsers(
                data: SettingsUsersListData(page: query.page, per: query.per),
                context: context(req)
            )
            try await req.audit(action: "read", entity: "settings_users", message: "list")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func updateRole(req: Request) async throws -> UserPublicResponse {
        do {
            let userID = try req.requireUUID("userID")
            let payload = try req.content.decode(SettingsUserRoleUpdateRequest.self)
            let response = try await req.application.services.settingsUserService.updateRole(
                data: SettingsUserRoleUpdateData(userID: userID, role: payload.role),
                context: context(req)
            )
            try await req.audit(action: "update", entity: "settings_users", entityID: userID, message: "role=\(payload.role.rawValue)")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func addItems(req: Request) async throws -> SettingsUserItemsOperationResponse {
        do {
            let userID = try req.requireUUID("userID")
            let payload = try req.content.decode(SettingsUserItemsAddRequest.self)
            let response = try await req.application.services.settingsUserService.addItems(
                data: SettingsUserItemsAddData(userID: userID, itemIDs: payload.itemIDs),
                context: context(req)
            )
            try await req.audit(action: "update", entity: "settings_users_items", entityID: userID, message: "add_items")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    func removeItems(req: Request) async throws -> SettingsUserItemsOperationResponse {
        do {
            let userID = try req.requireUUID("userID")
            let payload = try req.content.decode(SettingsUserItemsRemoveRequest.self)
            let response = try await req.application.services.settingsUserService.removeItems(
                data: SettingsUserItemsRemoveData(
                    userID: userID,
                    itemIDs: payload.itemIDs,
                    reassignToUserID: payload.reassignToUserID
                ),
                context: context(req)
            )
            try await req.audit(action: "update", entity: "settings_users_items", entityID: userID, message: "remove_items")
            return response
        } catch let error as DomainError {
            throw error.asAbort()
        }
    }

    private func context(_ req: Request) -> ServiceContext {
        ServiceContext(db: req.db, currentUser: req.auth.get(User.self))
    }
}
