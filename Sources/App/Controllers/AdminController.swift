import Fluent
import Vapor

struct AdminController: RouteCollection {
    private let username = "admin"
    private let password = "admin"
    private let defaultPer = 20
    private let maxPer = 100

    func boot(routes: RoutesBuilder) throws {
        routes.get("admin", use: index)
    }

    func index(req: Request) async throws -> View {
        guard isAuthorized(req: req) else {
            throw unauthorizedResponse()
        }

        let query = try req.query.decode(AdminAuditLogsQuery.self)
        let requestedPage = max(1, query.page ?? 1)
        let requestedPer = query.per ?? defaultPer
        let per = min(max(1, requestedPer), maxPer)

        let total = try await AuditLog.query(on: req.db).count()
        let totalPages = max(1, Int(ceil(Double(total) / Double(per))))
        let page = min(requestedPage, totalPages)
        let offset = (page - 1) * per
        let logs = try await AuditLog.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .sort(\.$id, .descending)
            .range(offset..<(offset + per))
            .all()

        let formatter = ISO8601DateFormatter()
        let context = AdminAuditLogPageContext(
            logs: logs.map { log in
                AdminAuditLogRowContext(
                    createdAt: log.createdAt.map { formatter.string(from: $0) } ?? "-",
                    action: log.action,
                    entity: log.entity,
                    entityID: log.entityID?.uuidString ?? "-",
                    message: log.message ?? "-",
                    metadata: log.metadata ?? "-"
                )
            },
            total: total,
            page: page,
            per: per,
            totalPages: totalPages,
            hasLogs: !logs.isEmpty,
            hasPrev: page > 1,
            hasNext: page < totalPages,
            prevUrl: "/admin?page=\(page - 1)&per=\(per)",
            nextUrl: "/admin?page=\(page + 1)&per=\(per)"
        )
        return try await req.view.render("admin", context)
    }

    private func isAuthorized(req: Request) -> Bool {
        guard let basic = req.headers.basicAuthorization else {
            return false
        }
        return basic.username == username && basic.password == password
    }

    private func unauthorizedResponse() -> Abort {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .wwwAuthenticate, value: "Basic realm=\"Admin\"")
        return Abort(.unauthorized, headers: headers, reason: "Unauthorized")
    }
}

private struct AdminAuditLogsQuery: Content {
    let page: Int?
    let per: Int?
}

private struct AdminAuditLogRowContext: Content {
    let createdAt: String
    let action: String
    let entity: String
    let entityID: String
    let message: String
    let metadata: String
}

private struct AdminAuditLogPageContext: Content {
    let logs: [AdminAuditLogRowContext]
    let total: Int
    let page: Int
    let per: Int
    let totalPages: Int
    let hasLogs: Bool
    let hasPrev: Bool
    let hasNext: Bool
    let prevUrl: String
    let nextUrl: String
}
