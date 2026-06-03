import XCTest

final class GemstoneDictionaryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDictionarySearchTaFindsTurquoise() throws {
        let app = launchApp(useTaQuery: true)
        openTab(index: 1, in: app)

        XCTAssertTrue(findStaticText("ターコイズ", in: app))
    }

    func testDictionarySearchJadeFindsJadeite() throws {
        let app = launchApp(dictionaryQuery: "jade")
        openTab(index: 1, in: app)

        XCTAssertTrue(app.staticTexts["翡翠"].waitForExistence(timeout: 8))
    }

    func testSupplementalCatalogSearchFindsDanburite() throws {
        let app = launchApp(dictionaryQuery: "danburite")
        openTab(index: 1, in: app)

        XCTAssertTrue(app.staticTexts["ダンビュライト"].waitForExistence(timeout: 8))
    }

    func testMarketListAndDemoSampleAreReachable() throws {
        let app = launchApp()

        openTab(index: 2, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["marketPriceList"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "155")).firstMatch.waitForExistence(timeout: 8))

        openTab(index: 0, in: app)
        let sampleButton = app.descendants(matching: .any)["demoSample-jadeite"]
        XCTAssertTrue(sampleButton.waitForExistence(timeout: 8))
        sampleButton.tap()
        XCTAssertTrue(app.staticTexts["翡翠"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "市場価格")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "サイズ信頼度")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "見かけサイズ")).firstMatch.waitForExistence(timeout: 8))
    }

    private func launchApp(dictionaryQuery: String? = nil, useTaQuery: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if useTaQuery {
            app.launchEnvironment["UITEST_DICTIONARY_QUERY_TA"] = "1"
        }
        if let dictionaryQuery {
            app.launchEnvironment["UITEST_DICTIONARY_QUERY"] = dictionaryQuery
        }
        app.launch()
        return app
    }

    private func openTab(index: Int, in app: XCUIApplication) {
        let tab = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }

    private func findStaticText(_ label: String, in app: XCUIApplication) -> Bool {
        let text = app.staticTexts[label]
        if text.waitForExistence(timeout: 4) {
            return true
        }
        for _ in 0..<8 {
            app.swipeUp()
            if text.waitForExistence(timeout: 2) {
                return true
            }
        }
        return false
    }
}
