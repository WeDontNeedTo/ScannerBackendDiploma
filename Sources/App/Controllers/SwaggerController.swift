import Foundation
import Vapor

struct SwaggerController: RouteCollection {
    private let docs: [String: String] = [
        "auth": "openapi-auth.yaml",
        "users": "openapi-users.yaml",
        "inventory": "openapi-inventory.yaml"
    ]

    func boot(routes: RoutesBuilder) throws {
        routes.get("docs", use: docsIndex)
        routes.get("docs", ":name", use: openAPIDoc)
        routes.get("swagger", use: swaggerUI)
    }

    private func docsIndex(req: Request) throws -> Response {
        let links = docs.keys.sorted().map { name in
            "<li><a href=\"/swagger?spec=\(name)\">\(name)</a></li>"
        }.joined()

        let html = """
        <!doctype html>
        <html lang="en">
          <head><meta charset="utf-8"><title>OpenAPI docs</title></head>
          <body>
            <h2>OpenAPI docs</h2>
            <ul>\(links)</ul>
          </body>
        </html>
        """

        var headers = HTTPHeaders()
        headers.contentType = .html
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    private func openAPIDoc(req: Request) throws -> Response {
        guard
            let name = req.parameters.get("name"),
            let filename = docs[name]
        else {
            throw Abort(.notFound, reason: "Unknown OpenAPI spec")
        }

        let path = req.application.directory.workingDirectory + "docs/" + filename
        guard FileManager.default.fileExists(atPath: path) else {
            throw Abort(.notFound, reason: "OpenAPI file not found")
        }
        return req.fileio.streamFile(at: path)
    }

    private func swaggerUI(req: Request) throws -> Response {
        let requestedSpec = req.query[String.self, at: "spec"] ?? "inventory"
        let activeSpec = docs[requestedSpec] == nil ? "inventory" : requestedSpec

        let options = docs.keys.sorted().map { name in
            let selected = name == activeSpec ? " selected" : ""
            return "<option value=\"" + name + "\"" + selected + ">" + name + "</option>"
        }.joined()

        let html = """
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>Swagger UI</title>
            <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
            <style>body { margin: 0; } #bar { padding: 12px; } #swagger-ui { height: calc(100vh - 56px); }</style>
          </head>
          <body>
            <div id="bar">
              <label for="spec">Spec:</label>
              <select id="spec">\(options)</select>
            </div>
            <div id="swagger-ui"></div>
            <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
            <script>
              const select = document.getElementById('spec');
              function loadSpec(name) {
                window.history.replaceState({}, '', '/swagger?spec=' + encodeURIComponent(name));
                window.ui = SwaggerUIBundle({
                  url: '/docs/' + name,
                  dom_id: '#swagger-ui'
                });
              }
              select.addEventListener('change', (event) => loadSpec(event.target.value));
              loadSpec(select.value);
            </script>
          </body>
        </html>
        """

        var headers = HTTPHeaders()
        headers.contentType = .html
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }
}
