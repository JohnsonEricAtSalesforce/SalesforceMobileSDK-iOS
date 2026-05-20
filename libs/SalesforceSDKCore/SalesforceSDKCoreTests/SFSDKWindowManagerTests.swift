/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
@testable import SalesforceSDKCore

class SFSDKWindowManagerDelegateTest: NSObject, SFSDKWindowManagerDelegate {
    var before: XCTestExpectation
    var after: XCTestExpectation
    var notificationWindow: SFSDKWindowContainer?

    init(before: XCTestExpectation, after: XCTestExpectation) {
        self.before = before
        self.after = after
        super.init()
    }

    func windowManager(_ windowManager: SFSDKWindowManager, willPresentWindow window: SFSDKWindowContainer) {
        notificationWindow = window
        before.fulfill()
    }

    func windowManager(_ windowManager: SFSDKWindowManager, didPresentWindow window: SFSDKWindowContainer) {
        notificationWindow = window
        after.fulfill()
    }

    func windowManager(_ windowManager: SFSDKWindowManager, willDismissWindow window: SFSDKWindowContainer) {
        notificationWindow = window
        before.fulfill()
    }

    func windowManager(_ windowManager: SFSDKWindowManager, didDismissWindow window: SFSDKWindowContainer) {
        notificationWindow = window
        after.fulfill()
    }
}

class SFSDKWindowContainerDelegateTest: NSObject, SFSDKWindowContainerDelegate {
    var enabledWindow: XCTestExpectation
    var disabledWindow: XCTestExpectation
    var notificationWindow: SFSDKWindowContainer?

    init(enabledWindow: XCTestExpectation, disabledWindow: XCTestExpectation) {
        self.enabledWindow = enabledWindow
        self.disabledWindow = disabledWindow
        super.init()
    }

    func presentWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?) {
        enabledWindow.fulfill()
    }

    func dismissWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?) {
        disabledWindow.fulfill()
    }
}

class SFSDKWindowManagerTests: XCTestCase {

    private var origApplicationWindow: UIWindow?

    override func setUp() {
        super.setUp()
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            origApplicationWindow = windowScene.windows.first
        }
    }

    override func tearDown() {
        origApplicationWindow?.makeKeyAndVisible()
        super.tearDown()
    }

    func testSetMainWindow() {
        XCTAssertNotNil(origApplicationWindow)
        guard let window = origApplicationWindow else { return }
        SFSDKWindowManager.shared.setMainUIWindow(window)
        XCTAssert(SFSDKWindowManager.shared.mainWindow(nil).window === window)
        XCTAssert(SFSDKWindowManager.shared.mainWindow(nil).window === window)
        let scene = SFApplicationHelper.sharedApplication()?.connectedScenes.first
        XCTAssert(SFSDKWindowManager.shared.mainWindow(scene).window === window)
    }

    func testLoginWindow() {
        let authWindowNilScene = SFSDKWindowManager.shared.authWindow(nil)
        XCTAssertNotNil(authWindowNilScene.window)
        XCTAssert(authWindowNilScene.windowType == .auth)

        let scene = SFApplicationHelper.sharedApplication()?.connectedScenes.first
        let authWindowScene = SFSDKWindowManager.shared.authWindow(scene)
        XCTAssertNotNil(authWindowScene.window)
        XCTAssert(authWindowScene.windowType == .auth)
        XCTAssertEqual(authWindowNilScene, authWindowScene)
    }

    func testScreenLockWindow() {
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        XCTAssertNotNil(screenLockWindow.window)
        XCTAssert(screenLockWindow.windowType == .screenLock)
    }

    func testSnapshotWindow() {
        let snapshotWindowNilScene = SFSDKWindowManager.shared.snapshotWindow(nil)
        XCTAssertNotNil(snapshotWindowNilScene.window)
        XCTAssert(snapshotWindowNilScene.windowType == .snapshot)

        let scene = SFApplicationHelper.sharedApplication()?.connectedScenes.first
        let snapshotWindowScene = SFSDKWindowManager.shared.snapshotWindow(scene)
        XCTAssertNotNil(snapshotWindowScene.window)
        XCTAssert(snapshotWindowScene.windowType == .snapshot)
        XCTAssertEqual(snapshotWindowNilScene, snapshotWindowScene)
    }

    func testCustomWindow() {
        let windowName = "test"
        let createdWindow = SFSDKWindowManager.shared.createNewNamedWindow(windowName)
        XCTAssertNotNil(createdWindow?.window)
        XCTAssert(createdWindow?.windowType == .other)

        let retrievedWindow = SFSDKWindowManager.shared.windowWithName(windowName)
        XCTAssertEqual(createdWindow, retrievedWindow)
    }

    func testEnable() {
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        screenLockWindow.presentWindow()
        XCTAssertNotNil(screenLockWindow.window)
        XCTAssertTrue(screenLockWindow.window?.isKeyWindow ?? false)
        XCTAssertTrue(screenLockWindow.isEnabled)
    }

    func testDisable() {
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        screenLockWindow.presentWindow()
        XCTAssertNotNil(screenLockWindow.window)
        XCTAssertTrue(screenLockWindow.window?.isKeyWindow ?? false)
        screenLockWindow.dismissWindow(animated: false, withCompletion: {
            XCTAssertFalse(screenLockWindow.window?.isKeyWindow ?? true)
            XCTAssertFalse(screenLockWindow.isEnabled)
        })
    }

    func testStyleOverride() {
        let snapshotWindow = SFSDKWindowManager.shared.snapshotWindow(nil)
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()

        // Check default
        XCTAssertEqual(snapshotWindow.window?.overrideUserInterfaceStyle, .unspecified)
        XCTAssertEqual(screenLockWindow.window?.overrideUserInterfaceStyle, .unspecified)

        // Set it directly
        SFSDKWindowManager.shared.userInterfaceStyle = .dark
        XCTAssertEqual(snapshotWindow.window?.overrideUserInterfaceStyle, .dark)
        XCTAssertEqual(screenLockWindow.window?.overrideUserInterfaceStyle, .dark)
    }

    func testActive() {
        let expectation = self.expectation(description: "ActiveWindow")

        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        screenLockWindow.presentWindow()
        let activeWindow = SFSDKWindowManager.shared.activeWindow(nil)
        XCTAssert(screenLockWindow === activeWindow)
        screenLockWindow.dismissWindow(animated: false, withCompletion: {
            XCTAssertFalse(screenLockWindow.window?.isKeyWindow ?? true)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10)
        let activeWindowAfter = SFSDKWindowManager.shared.activeWindow(nil)
        XCTAssert(screenLockWindow !== activeWindowAfter)
    }

    func testLevels() {
        // these 3 statements should not make any difference
        SFSDKWindowManager.shared.snapshotWindow(nil).window?.windowLevel = UIWindow.Level(rawValue: 1)
        SFSDKWindowManager.shared.screenLockWindow().window?.windowLevel = UIWindow.Level(rawValue: 4)
        SFSDKWindowManager.shared.authWindow(nil).window?.windowLevel = UIWindow.Level(rawValue: 3)
        XCTAssertTrue(SFSDKWindowManager.shared.snapshotWindow(nil).windowLevel != UIWindow.Level(rawValue: 1))
        XCTAssertTrue(SFSDKWindowManager.shared.screenLockWindow().windowLevel != UIWindow.Level(rawValue: 4))
        XCTAssertTrue(SFSDKWindowManager.shared.authWindow(nil).windowLevel != UIWindow.Level(rawValue: 3))
    }

    func testCompletionBlockForEnable() {
        let completionBlock = XCTestExpectation(description: "CompletionBlockCalled")
        SFSDKWindowManager.shared.authWindow(nil).presentWindow(animated: false, withCompletion: {
            completionBlock.fulfill()
        })
        wait(for: [completionBlock], timeout: 2)
    }

    func testCompletionBlockForDisable() {
        let completionBlock = XCTestExpectation(description: "CompletionBlockCalled")
        SFSDKWindowManager.shared.authWindow(nil).presentWindow()
        SFSDKWindowManager.shared.authWindow(nil).dismissWindow(animated: false, withCompletion: {
            completionBlock.fulfill()
        })
        wait(for: [completionBlock], timeout: 2)
    }

    func testDelegate() {
        let beforeEnablement = XCTestExpectation(description: "BeforeEnablement")
        let afterEnablement = XCTestExpectation(description: "AfterEnablement")
        let delegate = SFSDKWindowManagerDelegateTest(before: beforeEnablement, after: afterEnablement)

        SFSDKWindowManager.shared.addDelegate(delegate)
        SFSDKWindowManager.shared.authWindow(nil).presentWindow()

        wait(for: [beforeEnablement, afterEnablement], timeout: 2)

        let beforeDisablement = XCTestExpectation(description: "BeforeDisablement")
        let afterDisablement = XCTestExpectation(description: "AfterDisablement")
        delegate.before = beforeDisablement
        delegate.after = afterDisablement

        SFSDKWindowManager.shared.authWindow(nil).dismissWindow()
        wait(for: [beforeDisablement, afterDisablement], timeout: 2)

        XCTAssertTrue(delegate.notificationWindow?.isAuthWindow ?? false)
    }

    func testDealloc() {
        weak var container: SFSDKWindowContainer?
        autoreleasepool {
            container = SFSDKWindowManager.shared.createNewNamedWindow("customWindow")
            container?.presentWindow()
            _ = SFSDKWindowManager.shared.removeNamedWindow("customWindow")
        }

        let predicate = NSPredicate(format: "window == nil")
        let predicateExpectation = XCTNSPredicateExpectation(predicate: predicate, object: container)
        wait(for: [predicateExpectation], timeout: 10)
    }
}
