import XCTest

final class NotificationSettingsUITests: XCTestCase {
    @MainActor
    func testCustomAlertsAndIndependentChoices() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-home"]
        app.launch()

        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let notifications = app.buttons["Notifications"]
        XCTAssertTrue(notifications.waitForExistence(timeout: 5))
        XCTAssertLessThan(notifications.frame.minY, app.buttons["App Info"].frame.minY)
        notifications.tap()

        let recommended = app.switches["notifications-recommended"]
        let reached = app.switches["notifications-limit-reached"]
        if !recommended.waitForExistence(timeout: 3) {
            throw XCTSkip("This flow requires notification permission in iOS Settings.")
        }
        XCTAssertTrue(recommended.waitForExistence(timeout: 5))
        capture(app, name: "Notifications initial")
        XCTAssertEqual(recommended.value as? String, "1")
        recommended.tap()
        XCTAssertEqual(recommended.value as? String, "0")
        XCTAssertEqual(reached.value as? String, "1")

        let add = app.buttons["add-custom-alert"]
        if !add.isHittable { app.swipeUp() }
        add.tap()
        let save = app.buttons["save-custom-alert"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        capture(app, name: "Custom alert editor")
        save.tap()
        let first = app.buttons["custom-alert-80"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let second = app.buttons["custom-alert-1"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "35%")
        save.tap()
        XCTAssertTrue(app.buttons["custom-alert-35"].waitForExistence(timeout: 5))
        first.swipeLeft()
        app.buttons["Remove"].tap()
        XCTAssertFalse(first.exists)

        app.swipeUp()
        let badge = app.switches["notifications-badge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        badge.tap()
        XCTAssertEqual(badge.value as? String, "0")
        app.swipeDown()

        let back = app.buttons["Back"]
        back.tap()
        menu.tap()
        notifications.tap()
        XCTAssertTrue(app.buttons["custom-alert-35"].waitForExistence(timeout: 5))
        XCTAssertEqual(recommended.value as? String, "0")
        capture(app, name: "Notifications custom alerts")
    }

    @MainActor
    func testPermissionGateHidesPreferences() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-home"]
        app.launch()
        let menu = app.buttons["Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        app.buttons["Notifications"].tap()

        let recommended = app.switches["notifications-recommended"]
        if recommended.waitForExistence(timeout: 3) {
            XCTAssertTrue(app.switches["notifications-limit-reached"].exists)
        } else {
            let openSettings = app.buttons["Open Settings"]
            let enable = app.buttons["Enable Notifications"]
            XCTAssertTrue(openSettings.exists || enable.exists)
            XCTAssertFalse(app.switches["notifications-badge"].exists)
            XCTAssertFalse(app.buttons["add-custom-alert"].exists)
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
