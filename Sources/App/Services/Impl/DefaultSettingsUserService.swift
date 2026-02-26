import Foundation

struct DefaultSettingsUserService: SettingsUserService {
    private let userRepository: any UserRepository
    private let itemRepository: any ItemRepository
    private let defaultPage = 1
    private let defaultPer = 20
    private let maxPer = 100

    init(repositories: RepositoryContainer) {
        self.userRepository = repositories.userRepository
        self.itemRepository = repositories.itemRepository
    }

    func listUsers(data: SettingsUsersListData, context: ServiceContext) async throws -> SettingsUsersPageResponse {
        _ = try requireAdmin(context)

        let page = data.page ?? defaultPage
        let per = data.per ?? defaultPer
        guard page > 0, per > 0 else {
            throw DomainError.badRequest("Page and per must be greater than zero.")
        }
        let boundedPer = min(per, maxPer)

        let total = try await userRepository.count(on: context.db)
        let totalPages = max(1, Int(ceil(Double(total) / Double(boundedPer))))
        let effectivePage = min(page, totalPages)
        let users = try await userRepository.list(page: effectivePage, per: boundedPer, on: context.db)

        var rows: [SettingsUserRowResponse] = []
        rows.reserveCapacity(users.count)
        for user in users {
            let userID = try user.requireID()
            let assignedItems = try await itemRepository.listByResponsibleUserWithRelations(
                responsibleUserID: userID,
                on: context.db
            )
            rows.append(SettingsUserRowResponse(user: user.asPublic(), assignedItems: assignedItems))
        }

        return SettingsUsersPageResponse(
            users: rows,
            page: effectivePage,
            per: boundedPer,
            total: total,
            totalPages: totalPages,
            hasNext: effectivePage < totalPages
        )
    }

    func updateRole(data: SettingsUserRoleUpdateData, context: ServiceContext) async throws -> UserPublicResponse {
        _ = try requireAdmin(context)
        guard let user = try await userRepository.find(id: data.userID, on: context.db) else {
            throw DomainError.notFound("User not found.")
        }

        if data.role != .materiallyResponsiblePerson {
            let ownedCount = try await itemRepository.countByResponsibleUser(
                responsibleUserID: data.userID,
                on: context.db
            )
            guard ownedCount == 0 else {
                throw DomainError.conflict("Cannot change role while user has assigned items.")
            }
        }

        user.role = data.role
        try await userRepository.save(user, on: context.db)
        return user.asPublic()
    }

    func addItems(data: SettingsUserItemsAddData, context: ServiceContext) async throws -> SettingsUserItemsOperationResponse {
        _ = try requireAdmin(context)

        let uniqueItemIDs = Array(Set(data.itemIDs))
        guard !uniqueItemIDs.isEmpty else {
            throw DomainError.badRequest("itemIDs must not be empty.")
        }

        guard let targetUser = try await userRepository.find(id: data.userID, on: context.db) else {
            throw DomainError.notFound("User not found.")
        }
        guard targetUser.role == .materiallyResponsiblePerson else {
            throw DomainError.conflict("Target user must be materially_responsible_person.")
        }

        let items = try await itemRepository.findAllByIDs(uniqueItemIDs, on: context.db)
        guard items.count == uniqueItemIDs.count else {
            throw DomainError.notFound("One or more items not found.")
        }

        for item in items {
            item.$responsibleUser.id = data.userID
        }
        try await itemRepository.saveAll(items, on: context.db)

        let updated = try await itemRepository.findAllByIDsWithRelations(uniqueItemIDs, on: context.db)
        return SettingsUserItemsOperationResponse(userID: data.userID, items: updated)
    }

    func removeItems(data: SettingsUserItemsRemoveData, context: ServiceContext) async throws -> SettingsUserItemsOperationResponse {
        _ = try requireAdmin(context)

        let uniqueItemIDs = Array(Set(data.itemIDs))
        guard !uniqueItemIDs.isEmpty else {
            throw DomainError.badRequest("itemIDs must not be empty.")
        }
        guard data.userID != data.reassignToUserID else {
            throw DomainError.conflict("Source and target users must be different.")
        }

        guard let sourceUser = try await userRepository.find(id: data.userID, on: context.db) else {
            throw DomainError.notFound("Source user not found.")
        }
        guard sourceUser.role == .materiallyResponsiblePerson else {
            throw DomainError.conflict("Source user must be materially_responsible_person.")
        }

        guard let targetUser = try await userRepository.find(id: data.reassignToUserID, on: context.db) else {
            throw DomainError.notFound("Target user not found.")
        }
        guard targetUser.role == .materiallyResponsiblePerson else {
            throw DomainError.conflict("Target user must be materially_responsible_person.")
        }

        let items = try await itemRepository.findAllByIDs(uniqueItemIDs, on: context.db)
        guard items.count == uniqueItemIDs.count else {
            throw DomainError.notFound("One or more items not found.")
        }
        let mismatched = items.contains { $0.$responsibleUser.id != data.userID }
        guard !mismatched else {
            throw DomainError.conflict("One or more items are not assigned to source user.")
        }

        for item in items {
            item.$responsibleUser.id = data.reassignToUserID
        }
        try await itemRepository.saveAll(items, on: context.db)

        let updated = try await itemRepository.findAllByIDsWithRelations(uniqueItemIDs, on: context.db)
        return SettingsUserItemsOperationResponse(userID: data.reassignToUserID, items: updated)
    }
}

extension DefaultSettingsUserService {
    private func requireAdmin(_ context: ServiceContext) throws -> User {
        guard let user = context.currentUser else {
            throw DomainError.unauthorized("Unauthorized")
        }
        guard user.role == .admin else {
            throw DomainError.forbidden("This action requires admin role.")
        }
        return user
    }
}
