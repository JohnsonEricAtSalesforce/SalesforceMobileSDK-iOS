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

// Window level offsets from SFSDKWindowManager+Internal.h
private let SFWindowLevelScreenLockOffset: CGFloat = 100
private let SFWindowLevelAuthOffset: CGFloat = 120
private let SFWindowLevelSnapshotOffset: CGFloat = 1000

// MARK: - Delegate Test Classes

private class WindowManagerDelegateTest: NSObject, SFSDKWindowManagerDelegate {
    var before: XCTestExpectation!
    var after: XCTestExpectation!
    var notificationWindow: SFSDKWindowContainer?

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

final class SFSDKWindowManagerTestsSwift: XCTestCase {

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
        SFSDKWindowManager.shared.setMainUIWindow(origApplicationWindow!)
        XCTAssertTrue(SFSDKWindowManager.shared.mainWindow(nil).window === origApplicationWindow)
        let scene: UIScene? = SFApplicationHelper.sharedApplication()?.connectedScenes.first
        XCTAssertTrue(SFSDKWindowManager.shared.mainWindow(scene).window === origApplicationWindow)
    }

    func testLoginWindow() {
        let authWindowNilScene = SFSDKWindowManager.shared.authWindow(nil)
        XCTAssertNotNil(authWindowNilScene.window)
        XCTAssertEqual(authWindowNilScene.windowType, SFSDKWindowType.auth)
        XCTAssertEqual(authWindowNilScene.window?.windowLevel, UIWindow.Level(rawValue: SFWindowLevelAuthOffset))

        let scene: UIScene? = SFApplicationHelper.sharedApplication()?.connectedScenes.first
        let authWindowScene = SFSDKWindowManager.shared.authWindow(scene)
        XCTAssertNotNil(authWindowScene.window)
        XCTAssertEqual(authWindowScene.windowType, SFSDKWindowType.auth)
        XCTAssertEqual(authWindowNilScene, authWindowScene)
    }

    func testScreenLockWindow() {
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        XCTAssertNotNil(screenLockWindow.window)
        XCTAssertEqual(screenLockWindow.windowType, .screenLock)
        XCTAssertEqual(screenLockWindow.window?.windowLevel, UIWindow.Level(rawValue: SFWindowLevelScreenLockOffset))
    }

    func testSnapshotWindow() {
        let snapshotWindowNilScene = SFSDKWindowManager.shared.snapshotWindow(nil)
        XCTAssertNotNil(snapshotWindowNilScene.window)
        XCTAssertEqual(snapshotWindowNilScene.windowType, SFSDKWindowType.snapshot)

        let scene: UIScene? = SFApplicationHelper.sharedApplication()?.connectedScenes.first
        let snapshotWindowScene = SFSDKWindowManager.shared.snapshotWindow(scene)
        XCTAssertNotNil(snapshotWindowScene.window)
        XCTAssertEqual(snapshotWindowScene.windowType, SFSDKWindowType.snapshot)
        XCTAssertEqual(snapshotWindowNilScene, snapshotWindowScene)
        XCTAssertEqual(snapshotWindowScene.window?.windowLevel, UIWindow.Level(rawValue: SFWindowLevelSnapshotOffset))
    }

    func testCustomWindow() {
        let windowName = "test"
        let createdWindow = SFSDKWindowManager.shared.createNewNamedWindow(windowName)
        XCTAssertNotNil(createdWindow?.window)
        XCTAssertEqual(createdWindow?.windowType, SFSDKWindowType.other)

        let retrievedWindow = SFSDKWindowManager.shared.windowWithName(windowName)
        XCTAssertEqual(createdWindow, retrievedWindow)
    }

    func testEnable() {
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        screenLockWindow.presentWindow()
        XCTAssertNotNil(screenLockWindow.window)
        XCTAssertTrue(screenLockWindow.window!.isKeyWindow)
        XCTAssertTrue(screenLockWindow.isEnabled())
    }

    func testDisable() {
        let screenLockWindow = SFSDKWindowManager.shared.screenLockWindow()
        screenLockWindow.presentWindow()
        XCTAssertNotNil(screenLockWindow.window)
        XCTAssertTrue(screenLockWindow.window!.isKeyWindow)
        screenLockWindow.dismissWindowAnimated(false, withCompletion: {
            XCTAssertFalse(screenLockWindow.window!.isKeyWindow)
            XCTAssertFalse(screenLockWindow.isEnabled())
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
        var activeWindow = SFSDKWindowManager.shared.activeWindow(nil)
        XCTAssertTrue(screenLockWindow === activeWindow)
        screenLockWindow.dismissWindowAnimated(false, withCompletion: {
            XCTAssertFalse(screenLockWindow.window!.isKeyWindow)
            expectation.fulfill()
        })
        waitForExpectations(timeout: 10)
        activeWindow = SFSDKWindowManager.shared.activeWindow(nil)
        XCTAssertFalse(screenLockWindow === activeWindow)
    }

    func testLevels() {
        // These 3 statements should not make any difference
        SFSDKWindowManager.shared.snapshotWindow(nil).window?.windowLevel = UIWindow.Level(rawValue: 1)
        SFSDKWindowManager.shared.screenLockWindow().window?.windowLevel = UIWindow.Level(rawValue: 4)
        SFSDKWindowManager.shared.authWindow(nil).window?.windowLevel = UIWindow.Level(rawValue: 3)
        XCTAssertNotEqual(SFSDKWindowManager.shared.snapshotWindow(nil).windowLevel, UIWindow.Level(rawValue: 1))
        XCTAssertNotEqual(SFSDKWindowManager.shared.screenLockWindow().windowLevel, UIWindow.Level(rawValue: 4))
        XCTAssertNotEqual(SFSDKWindowManager.shared.authWindow(nil).windowLevel, UIWindow.Level(rawValue: 3))
    }

    func testCompletionBlockForEnable() {
        let completionBlock = XCTestExpectation(description: "CompletionBlockCalled")
        SFSDKWindowManager.shared.authWindow(nil).presentWindowAnimated(false, withCompletion: {
            completionBlock.fulfill()
        })
        wait(for: [completionBlock], timeout: 2)
    }

    func testCompletionBlockForDisable() {
        let completionBlock = XCTestExpectation(description: "CompletionBlockCalled")
        SFSDKWindowManager.shared.authWindow(nil).presentWindow()
        SFSDKWindowManager.shared.authWindow(nil).dismissWindowAnimated(false, withCompletion: {
            completionBlock.fulfill()
        })
        wait(for: [completionBlock], timeout: 2)
    }

    func testDelegate() {
        let delegate = WindowManagerDelegateTest()
        delegate.before = XCTestExpectation(description: "BeforeEnablement")
        delegate.after = XCTestExpectation(description: "AfterEnablement")

        SFSDKWindowManager.shared.addDelegate(delegate)
        SFSDKWindowManager.shared.authWindow(nil).presentWindow()

        wait(for: [delegate.before, delegate.after], timeout: 2)

        delegate.before = XCTestExpectation(description: "BeforeDisablement")
        delegate.after = XCTestExpectation(description: "AfterDisablement")

        SFSDKWindowManager.shared.authWindow(nil).dismissWindow()
        wait(for: [delegate.before, delegate.after], timeout: 2)

        XCTAssertTrue(delegate.notificationWindow!.isAuthWindow())
    }

    func testDealloc() {
        weak var container: SFSDKWindowContainer?
        autoreleasepool {
            container = SFSDKWindowManager.shared.createNewNamedWindow("customWindow")
            container?.presentWindow()
            SFSDKWindowManager.shared.removeNamedWindow("customWindow")
        }

        let predicate = NSPredicate { _, _ in
            return container?.window == nil
        }
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: container)
        wait(for: [exp], timeout: 10)
    }
}
