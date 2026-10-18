import XCTest

final class AppStoreScreenshots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureCoreExperience() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Next word"].waitForExistence(timeout: 15))
        capture("01-word-detail")

        app.buttons["Next word"].tap()
        XCTAssertTrue(app.buttons["Next word"].waitForExistence(timeout: 5))
        capture("02-next-word")

        app.tabBars.buttons["Seen"].tap()
        XCTAssertTrue(app.navigationBars["Seen words"].waitForExistence(timeout: 5))
        capture("03-seen-history")
    }

    @MainActor
    func testCaptureWidget() throws {
        let app = XCUIApplication()
        app.launch()
        app.terminate()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.55)).press(forDuration: 1.5)

        let addWidget = springboard.buttons["Add Widget"]
        XCTAssertTrue(addWidget.waitForExistence(timeout: 5))
        addWidget.tap()

        let search = springboard.searchFields["Search Widgets"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Spanish Word")

        let result = springboard.cells.containing(.staticText, identifier: "Spanish Word").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.93)).tap()

        let done = springboard.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertFalse(done.waitForExistence(timeout: 5))
        capture("04-home-screen-widget")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
