/*
 SFUIWindowManager.swift
 SalesforceSDKCore

 Created by Raj Rao on 7/4/17.

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

import Foundation
import UIKit

/// Delegate of the SFSDKWindowManager
@objc public protocol SFSDKWindowManagerDelegate: AnyObject {

    /// Called when the window will be made opaque
    /// - Parameters:
    ///   - windowManager: The window manager making this call
    ///   - window: The window that will be made opaque
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, willPresentWindow window: SFSDKWindowContainer)

    /// Called when the window has been made opaque
    /// - Parameters:
    ///   - windowManager: The window manager making this call
    ///   - window: The window that has been made opaque
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, didPresentWindow window: SFSDKWindowContainer)

    /// Called when the window will be made transparent
    /// - Parameters:
    ///   - windowManager: The window manager making this call
    ///   - window: The window will be made transparent
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, willDismissWindow window: SFSDKWindowContainer)

    /// Called when the window is made transparent
    /// - Parameters:
    ///   - windowManager: The window manager making this call
    ///   - window: The window that has been made transparent
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, didDismissWindow window: SFSDKWindowContainer)
}

@objc(SFSDKUIWindow)
@objcMembers
public class SFSDKUIWindow: UIWindow {
    public private(set) var windowName: String?
    public var stashedController: UIViewController?
    private var deallocating = false

    public override init(frame: CGRect) {
        windowName = "NONAME"
        super.init(frame: frame)
    }

    public init(frame: CGRect, andName windowName: String) {
        self.windowName = windowName
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func stashRootViewController() {
        if let rootViewController = rootViewController {
            stashedController = rootViewController
            super.rootViewController = nil
        }
    }

    func unstashRootViewController() {
        if let stashed = stashedController {
            super.rootViewController = stashed
        }
    }

    public override var rootViewController: UIViewController? {
        get {
            return super.rootViewController
        }
        set {
            stashedController = newValue
            super.rootViewController = newValue
        }
    }

    public override func makeKeyAndVisible() {
        super.makeKeyAndVisible()
        if let sceneId = windowScene?.session.persistentIdentifier {
            SFSDKWindowManager.shared.lastKeyWindows.setObject(self, forKey: sceneId as NSString)
        }
    }

    public override func becomeKey() {
        unstashRootViewController()
        if windowLevel.rawValue < 0 {
            windowLevel = UIWindow.Level(rawValue: windowLevel.rawValue * -1)
        }
        alpha = 1.0
        super.becomeKey()
    }

    public override func resignKey() {
        if SFApplicationHelper.sharedApplication()?.supportsMultipleScenes == true || SFSDKMacDetectUtil.isOnMac() {
            // Automatically disabling the window breaks in these cases, apps should use makeTransparentWithCompletion if needed
            super.resignKey()
            return
        }

        disableWindow()
        super.resignKey()
    }

    func disableWindow() {
        if deallocating {
            SFSDKCoreLogger.i(type(of: self), message: "Skipping disableWindow for \(windowName ?? "") window because it's deallocating")
            return
        }

        let isActive = windowScene?.activationState == .foregroundActive ||
                      windowScene?.activationState == .foregroundInactive

        if isSnapshotWindow() || isActive {
            if windowLevel.rawValue > 0 {
                windowLevel = UIWindow.Level(rawValue: windowLevel.rawValue * -1)
            }
            alpha = 0.0
            super.rootViewController = nil
            stashRootViewController()
        }
    }

    deinit {
        deallocating = true
    }

    private func isSnapshotWindow() -> Bool {
        return windowName == kSFSnaphotWindowKey
    }

    private func isScreenLockWindow() -> Bool {
        return SFSDKWindowManager.shared.activeWindow(nil)?.windowName == kSFScreenLockWindowKey
    }
}

private let kSFMainWindowKey = "main"
private let kSFLoginWindowKey = "auth"
private let kSFSnaphotWindowKey = "snapshot"
private let kSFScreenLockWindowKey = "screenlock"

private let SFWindowLevelScreenLockOffset: CGFloat = 100
private let SFWindowLevelAuthOffset: CGFloat = 120
private let SFWindowLevelSnapshotOffset: CGFloat = 1000

@objc(SFSDKWindowManager)
@objcMembers
public class SFSDKWindowManager: NSObject {

    /// Sets overrideUserInterfaceStyle on managed windows. Default is UIUserInterfaceStyleUnspecified.
    public var userInterfaceStyle: UIUserInterfaceStyle = .unspecified {
        didSet {
            for sceneWindows in namedWindows.objectEnumerator() ?? NSEnumerator() {
                guard let windowTable = sceneWindows as? NSMapTable<NSString, SFSDKWindowContainer> else { continue }
                for container in windowTable.objectEnumerator() ?? NSEnumerator() {
                    (container as? SFSDKWindowContainer)?.window?.overrideUserInterfaceStyle = userInterfaceStyle
                }
            }
        }
    }

    private var delegates: NSHashTable<NSValue>
    private let namedWindows: NSMapTable<NSString, NSMapTable<NSString, SFSDKWindowContainer>>
    fileprivate let lastActiveWindows: NSMapTable<NSString, SFSDKWindowContainer>
    fileprivate let lastKeyWindows: NSMapTable<NSString, UIWindow>

    public static let shared: SFSDKWindowManager = {
        return SFSDKWindowManager()
    }()

    private override init() {
        namedWindows = NSMapTable(keyOptions: .strongMemory, valueOptions: .strongMemory)
        delegates = NSHashTable.weakObjects()
        lastActiveWindows = NSMapTable.strongToWeakObjects()
        lastKeyWindows = NSMapTable.strongToWeakObjects()
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidDisconnect(_:)), name: UIScene.didDisconnectNotification, object: nil)
    }

    // MARK: - Window Access Methods

    /// SDK uses this window to present the screen lock view.
    public func screenLockWindow() -> SFSDKWindowContainer {
        return screenLockWindow(nil)
    }

    /// SDK uses this window to present the login flow for the given scene. Defaults a connected scene if one isn't provided.
    public func authWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let scene = nonnullScene(scene)
        var container = containerForWindowKey(kSFLoginWindowKey, scene: scene)

        if container == nil {
            container = createAuthWindow(forScene: scene)
        }
        setWindowScene(container!, scene: scene)
        container!.windowLevel = UIWindow.Level(rawValue: mainWindow(scene).window!.windowLevel.rawValue + SFWindowLevelAuthOffset)
        return container!
    }

    /// SDK uses this window to present the snapshot view for a given scene. Defaults to a connected scene if one isn't provided.
    public func snapshotWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let scene = nonnullScene(scene)
        var container = containerForWindowKey(kSFSnaphotWindowKey, scene: scene)
        if container == nil {
            container = createSnapshotWindow(forScene: scene)
        }
        setWindowScene(container!, scene: scene)
        container!.windowLevel = UIWindow.Level(rawValue: mainWindow(scene).window!.windowLevel.rawValue + SFWindowLevelSnapshotOffset)
        return container!
    }

    /// Returns the SFSDKWindowContainer window representing the mainWindow that has been set for a given scene. Defaults to a connected scene if one isn't provided.
    public func mainWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let scene = nonnullScene(scene)
        var mainWindow = containerForWindowKey(kSFMainWindowKey, scene: scene)

        if mainWindow == nil {
            if let keyWindow = findActiveWindow(forScene: scene) {
                lastKeyWindows.setObject(keyWindow, forKey: scene.session.persistentIdentifier as NSString)
                setMainUIWindow(keyWindow, scene: scene)
            }
        }
        return (namedWindows.object(forKey: scene.session.persistentIdentifier as NSString))?.object(forKey: kSFMainWindowKey as NSString) ?? SFSDKWindowContainer(name: "temp")
    }

    /// Returns the SFSDKWindowContainer window representing the active presented window that has been set for a given scene. Defaults to a connected scene if one isn't provided.
    public func activeWindow(_ scene: UIScene?) -> SFSDKWindowContainer? {
        let scene = nonnullScene(scene)
        guard let activeWindow = findActiveWindow(forScene: scene),
              let sceneWindows = namedWindows.object(forKey: scene.session.persistentIdentifier as NSString) else {
            return nil
        }

        for container in sceneWindows.objectEnumerator() ?? NSEnumerator() {
            guard let container = container as? SFSDKWindowContainer else { continue }
            if container.isEnabled() && container.window == activeWindow {
                return container
            }
        }
        return nil
    }

    public func screenLockWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let scene = nonnullScene(scene)
        var container = containerForWindowKey(kSFScreenLockWindowKey, scene: scene)
        if container == nil {
            container = createScreenLockWindow(forScene: scene)
        }
        setWindowScene(container!, scene: scene)
        container!.windowLevel = UIWindow.Level(rawValue: mainWindow(scene).window!.windowLevel.rawValue + SFWindowLevelScreenLockOffset)
        return container!
    }

    /// Used to setup the main application window.
    public func setMainUIWindow(_ window: UIWindow) {
        setMainUIWindow(window, scene: nil)
    }

    /// Used to setup the main window for a given scene. Defaults to a connected scene if one isn't provided.
    public func setMainUIWindow(_ window: UIWindow, scene: UIScene?) {
        let scene = nonnullScene(scene)
        let container = SFSDKWindowContainer(window: window, name: kSFMainWindowKey)
        container.windowType = .main
        container.windowDelegate = self
        container.window?.alpha = 1.0
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: kSFMainWindowKey, scene: scene)
    }

    /// Used to create a new Window keyed by a specified name
    public func createNewNamedWindow(_ windowName: String) -> SFSDKWindowContainer? {
        return createNewNamedWindow(windowName, scene: nil)
    }

    /// Used to create a new window keyed by a specified name for a given scene. Defaults to a  connected scene if one isn't provided.
    public func createNewNamedWindow(_ windowName: String, scene: UIScene?) -> SFSDKWindowContainer? {
        let scene = nonnullScene(scene)
        guard !isReservedName(windowName) else { return nil }

        let container = SFSDKWindowContainer(name: windowName)
        container.windowDelegate = self
        container.windowLevel = .normal
        container.windowType = .other
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: windowName, scene: scene)
        return container
    }

    /// Used to remove a Window by a specified name
    public func removeNamedWindow(_ windowName: String) -> Bool {
        return removeNamedWindow(windowName, scene: nil)
    }

    /// Used to remove a window by a specified name for a given scene. Defaults to a connected scene if one isn't provided.
    public func removeNamedWindow(_ windowName: String, scene: UIScene?) -> Bool {
        let scene = nonnullScene(scene)
        guard !isReservedName(windowName) else { return false }

        namedWindows.object(forKey: scene.session.persistentIdentifier as NSString)?.removeObject(forKey: windowName as NSString)
        return true
    }

    /// Used to retrieve a Window by a specified name
    public func windowWithName(_ name: String) -> SFSDKWindowContainer? {
        return windowWithName(name, scene: nil)
    }

    /// Used to retrieve a window by a specified name for a given scene. Defaults to a connected scene if one isn't provided.
    public func windowWithName(_ name: String, scene: UIScene?) -> SFSDKWindowContainer? {
        let scene = nonnullScene(scene)
        let container = namedWindows.object(forKey: scene.session.persistentIdentifier as NSString)?.object(forKey: name as NSString)
        if let container = container {
            setWindowScene(container, scene: scene)
        }
        return container
    }

    // MARK: - Delegate Management

    /// Add a Window Manager Delegate
    public func addDelegate(_ delegate: SFSDKWindowManagerDelegate) {
        objc_sync_enter(self)
        delegates.add(NSValue(nonretainedObject: delegate))
        objc_sync_exit(self)
    }

    /// Remove a Window Manager Delegate
    public func removeDelegate(_ delegate: SFSDKWindowManagerDelegate) {
        objc_sync_enter(self)
        delegates.remove(NSValue(nonretainedObject: delegate))
        objc_sync_exit(self)
    }

    private func enumerateDelegates(_ block: (SFSDKWindowManagerDelegate) -> Void) {
        objc_sync_enter(self)
        for obj in delegates.allObjects {
            if let delegate = (obj as? NSValue)?.nonretainedObjectValue as? SFSDKWindowManagerDelegate {
                block(delegate)
            }
        }
        objc_sync_exit(self)
    }

    // MARK: - Private Methods

    private func containerForWindowKey(_ window: String, scene: UIScene) -> SFSDKWindowContainer? {
        return namedWindows.object(forKey: scene.session.persistentIdentifier as NSString)?.object(forKey: window as NSString)
    }

    private func setContainer(_ window: SFSDKWindowContainer, windowKey: String, scene: UIScene) {
        let scene = nonnullScene(scene)
        var sceneWindows = namedWindows.object(forKey: scene.session.persistentIdentifier as NSString)
        if sceneWindows == nil {
            sceneWindows = NSMapTable(keyOptions: .strongMemory, valueOptions: .strongMemory)
            sceneWindows?.setObject(window, forKey: windowKey as NSString)
            namedWindows.setObject(sceneWindows, forKey: scene.session.persistentIdentifier as NSString)
        } else {
            namedWindows.object(forKey: scene.session.persistentIdentifier as NSString)?.setObject(window, forKey: windowKey as NSString)
        }
    }

    private func setWindowScene(_ container: SFSDKWindowContainer, scene: UIScene) {
        let scene = nonnullScene(scene)
        if container.window?.windowScene != scene {
            container.window?.windowScene = scene as? UIWindowScene
        }
        container.window?.frame = container.window?.windowScene?.coordinateSpace.bounds ?? .zero
    }

    private func isReservedName(_ windowName: String) -> Bool {
        return windowName == kSFMainWindowKey ||
               windowName == kSFLoginWindowKey ||
               windowName == kSFScreenLockWindowKey ||
               windowName == kSFSnaphotWindowKey
    }

    private func createSnapshotWindow(forScene scene: UIScene) -> SFSDKWindowContainer {
        let container = SFSDKWindowContainer(name: kSFSnaphotWindowKey)
        container.windowDelegate = self
        container.windowType = .snapshot
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: kSFSnaphotWindowKey, scene: scene)
        return container
    }

    private func createAuthWindow(forScene scene: UIScene) -> SFSDKWindowContainer {
        let container = SFSDKWindowContainer(name: kSFLoginWindowKey)
        container.windowDelegate = self
        container.windowType = .auth
        setContainer(container, windowKey: kSFLoginWindowKey, scene: scene)
        return container
    }

    private func createScreenLockWindow(forScene scene: UIScene) -> SFSDKWindowContainer {
        let container = SFSDKWindowContainer(name: kSFScreenLockWindowKey)
        container.windowDelegate = self
        container.windowType = .screenLock
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: kSFScreenLockWindowKey, scene: scene)
        return container
    }

    private func findActiveWindow(forScene scene: UIScene) -> UIWindow? {
        let scene = nonnullScene(scene)
        var mainWindow = lastKeyWindows.object(forKey: scene.session.persistentIdentifier as NSString)

        if mainWindow == nil, let sceneDelegate = scene.delegate, sceneDelegate.responds(to: #selector(getter: UIWindowSceneDelegate.window)) {
            mainWindow = sceneDelegate.perform(#selector(getter: UIWindowSceneDelegate.window))?.takeUnretainedValue() as? UIWindow
        } else if mainWindow == nil, let app = SFApplicationHelper.sharedApplication(), let appDelegate = app.delegate, appDelegate.responds(to: #selector(getter: UIApplicationDelegate.window)) {
            mainWindow = appDelegate.window ?? nil
        }

        if let windowScene = scene as? UIWindowScene {
            for window in windowScene.windows where window.isKeyWindow {
                mainWindow = window
                break
            }
        }
        return mainWindow
    }

    private func nonnullScene(_ scene: UIScene?) -> UIScene {
        return scene ?? defaultScene()
    }

    public func defaultScene() -> UIScene {
        let connectedScenes = Array(SFApplicationHelper.sharedApplication()?.connectedScenes ?? [])
        for connectedScene in connectedScenes {
            if connectedScene.activationState == .foregroundActive {
                return connectedScene
            } else if connectedScene.activationState == .foregroundInactive {
                return connectedScene
            }
        }
        return connectedScenes.first!
    }

    @objc private func sceneDidDisconnect(_ notification: Notification) {
        guard let scene = notification.object as? UIScene else { return }
        namedWindows.removeObject(forKey: scene.session.persistentIdentifier as NSString)
    }

    private func makeTransparentWithCompletion(_ window: SFSDKWindowContainer, completion: (() -> Void)?) {
        guard let scene = window.window?.windowScene else {
            completion?()
            return
        }
        var fallbackWindow = mainWindow(scene)

        if window.isSnapshotWindow() || window.isScreenLockWindow() {
            let sceneId = scene.session.persistentIdentifier as NSString
            if let lastActive = lastActiveWindows.object(forKey: sceneId) {
                fallbackWindow = lastActive
                lastActiveWindows.removeObject(forKey: sceneId)
            }
        }

        if let sfWindow = window.window as? SFSDKUIWindow {
            sfWindow.disableWindow()
        }

        if !window.isMainWindow() {
            namedWindows.object(forKey: scene.session.persistentIdentifier as NSString)?.removeObject(forKey: window.windowName as NSString)
        }

        fallbackWindow.window?.makeKeyAndVisible()

        enumerateDelegates { delegate in
            delegate.windowManager?(self, didDismissWindow: window)
        }

        completion?()
    }

    private func makeOpaqueWithCompletion(_ window: SFSDKWindowContainer, completion: (() -> Void)?) {
        guard let scene = window.window?.windowScene else {
            completion?()
            return
        }

        if window.isSnapshotWindow() {
            if let activeWindow = activeWindow(scene), !activeWindow.isSnapshotWindow() {
                lastActiveWindows.setObject(activeWindow, forKey: scene.session.persistentIdentifier as NSString)
            }
        }

        if window.isScreenLockWindow() {
            if let activeWindow = activeWindow(scene), !activeWindow.isScreenLockWindow() {
                lastActiveWindows.setObject(activeWindow, forKey: scene.session.persistentIdentifier as NSString)
            }
        }

        if window.isEnabled() {
            completion?()
            return
        }

        window.window?.makeKeyAndVisible()
        enumerateDelegates { delegate in
            delegate.windowManager?(self, didPresentWindow: window)
        }
        completion?()
    }
}

// MARK: - SFSDKWindowContainerDelegate

extension SFSDKWindowManager: SFSDKWindowContainerDelegate {
    public func presentWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                presentWindow(window, animated: animated, withCompletion: completion)
            }
            return
        }

        enumerateDelegates { delegate in
            delegate.windowManager?(self, willPresentWindow: window)
        }

        if animated {
            let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
                window.window?.alpha = 1.0
            }
            animator.startAnimation()
            makeOpaqueWithCompletion(window, completion: completion)
        } else {
            makeOpaqueWithCompletion(window, completion: completion)
        }
    }

    public func dismissWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                dismissWindow(window, animated: animated, withCompletion: completion)
            }
            return
        }

        if !window.isEnabled() {
            completion?()
            return
        }

        enumerateDelegates { delegate in
            delegate.windowManager?(self, willDismissWindow: window)
        }

        if animated {
            let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
                window.window?.alpha = 0.0
            }
            animator.startAnimation()
            makeTransparentWithCompletion(window, completion: completion)
        } else {
            makeTransparentWithCompletion(window, completion: completion)
        }
    }
}
