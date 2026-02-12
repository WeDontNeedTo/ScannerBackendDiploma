import App
import XCTVapor

final class AppTests: XCTestCase {
    func testHealthCheck() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor API is running")
        }
    }
}
