//
//  MujoUITests.swift
//  MujoUITests
//
//  Created by Aikari Studio on 05/09/2026.
//

import XCTest

final class MujoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLimitSheetCanDismissAfterCancelledDrag() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-home")
        app.launch()

        let openEditor = app.buttons["Change daily limit"]
        XCTAssertTrue(openEditor.waitForExistence(timeout: 10))
        openEditor.tap()
        let heading = app.staticTexts["daily-limit-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let originalY = heading.frame.minY

        for _ in 0..<3 {
            let start = heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            // Move slightly downward, then hold so this is a cancelled dismissal,
            // not a fast flick that would legitimately close the sheet.
            start.press(
                forDuration: 0.1,
                thenDragTo: start.withOffset(CGVector(dx: 0, dy: 65)),
                withVelocity: .slow,
                thenHoldForDuration: 0.8
            )
            XCTAssertTrue(heading.exists)
            let returned = NSPredicate { _, _ in
                heading.exists && abs(heading.frame.minY - originalY) < 5
            }
            expectation(for: returned, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
        }

        let start = heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        start.press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)),
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
        XCTAssertTrue(heading.waitForNonExistence(timeout: 5))
        openEditor.tap()
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAppInfoUsesBackNavigation() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-home")
        app.launch()

        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()

        let appInfoMenuItem = app.buttons["App Info"]
        XCTAssertTrue(appInfoMenuItem.waitForExistence(timeout: 5))
        appInfoMenuItem.tap()

        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Privacy Policy"].exists)

        backButton.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(backButton.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testAppInfoCreditsExpandInline() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-home")
        app.launch()

        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()

        let appInfoMenuItem = app.buttons["App Info"]
        XCTAssertTrue(appInfoMenuItem.waitForExistence(timeout: 5))
        appInfoMenuItem.tap()

        let credits = app.buttons["credits-disclosure"]
        XCTAssertTrue(credits.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Sakura petal artwork"].exists)

        credits.tap()

        XCTAssertTrue(
            app.staticTexts["Sakura petal artwork"]
                .waitForExistence(timeout: 2)
        )
        let sourceLink = app.descendants(matching: .any)[
            "artwork-source-link"
        ]
        XCTAssertTrue(sourceLink.waitForExistence(timeout: 2))
        XCTAssertEqual(
            sourceLink.label,
            "Image by user15245033 on Magnific"
        )
        XCTAssertFalse(app.descendants(matching: .any)["View source"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
