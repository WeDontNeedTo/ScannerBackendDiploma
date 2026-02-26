protocol SettingsUserService {
    func listUsers(data: SettingsUsersListData, context: ServiceContext) async throws -> SettingsUsersPageResponse
    func updateRole(data: SettingsUserRoleUpdateData, context: ServiceContext) async throws -> UserPublicResponse
    func addItems(data: SettingsUserItemsAddData, context: ServiceContext) async throws -> SettingsUserItemsOperationResponse
    func removeItems(data: SettingsUserItemsRemoveData, context: ServiceContext) async throws -> SettingsUserItemsOperationResponse
}
