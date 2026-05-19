// SFSDKWindowManager.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 7/4/17.
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

// Window level offsets
private let SFWindowLevelScreenLockOffset: CGFloat = 100
private let SFWindowLevelAuthOffset: CGFloat = 120
private let SFWindowLevelSnapshotOffset: CGFloat = 1000

// Window keys
private let kSFMainWindowKey = "main"
private let kSFLoginWindowKey = "auth"
private let kSFSnapshotWindowKey = "snapshot"
private let kSFScreenLockWindowKey = "screenlock"

@objc(SFSDKWindowManagerDelegate)
public protocol SFSDKWindowManagerDelegate: AnyObject {
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, willPresentWindow window: SFSDKWindowContainer)
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, didPresentWindow window: SFSDKWindowContainer)
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, willDismissWindow window: SFSDKWindowContainer)
    @objc optional func windowManager(_ windowManager: SFSDKWindowManager, didDismissWindow window: SFSDKWindowContainer)
}

/// SFSDKUIWindow - Extended UIWindow with stash/unstash capabilities.
@objc(SFSDKUIWindow)
@objcMembers
public class SFSDKUIWindow: UIWindow {
    @objc public var stashedController: UIViewController?
    @objc public private(set) var windowName: String?
    private var deallocating = false

    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        windowName = "NONAME"
    }

    @objc public init(frame: CGRect, andName windowName: String) {
        super.init(frame: frame)
        self.windowName = windowName
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        windowName = "NONAME"
    }

    func stashRootViewController() {
        if rootViewController != nil {
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
        get { return super.rootViewController }
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
    }

    public override func resignKey() {
        if SFApplicationHelper.sharedApplication()?.supportsMultipleScenes == true || SFSDKMacDetectUtil.isOnMac() {
            return
        }
        disableWindow()
    }

    func disableWindow() {
        guard !deallocating else {
            SFSDKCoreLogger.i(SFSDKUIWindow.self, message: "Skipping disableWindow for \(windowName ?? "") window because it's deallocating")
            return
        }
        let isActive = windowScene?.activationState == .foregroundActive || windowScene?.activationState == .foregroundInactive
        if isSnapshotWindow || isActive {
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

    private var isSnapshotWindow: Bool {
        return windowName == kSFSnapshotWindowKey
    }
}

/// SFSDKWindowManager - Manages multiple UIWindow instances for auth/login UI.
@objc(SFSDKWindowManager)
@objcMembers
public class SFSDKWindowManager: NSObject, SFSDKWindowContainerDelegate {

    @objc public static let shared = SFSDKWindowManager()

    @objc public var userInterfaceStyle: UIUserInterfaceStyle = .unspecified {
        didSet {
            let sceneEnumerator = namedWindows.objectEnumerator()
            while let sceneWindows = sceneEnumerator?.nextObject() as? NSMapTable<NSString, SFSDKWindowContainer> {
                let windowEnumerator = sceneWindows.objectEnumerator()
                while let container = windowEnumerator?.nextObject() as? SFSDKWindowContainer {
                    container.window?.overrideUserInterfaceStyle = userInterfaceStyle
                }
            }
        }
    }

    private let delegates = NSHashTable<AnyObject>.weakObjects()
    private let namedWindows = NSMapTable<NSString, NSMapTable<NSString, SFSDKWindowContainer>>.strongToStrongObjects()
    private let lastActiveWindows = NSMapTable<NSString, SFSDKWindowContainer>.strongToWeakObjects()
    internal let lastKeyWindows = NSMapTable<NSString, UIWindow>.strongToWeakObjects()

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidDisconnect(_:)), name: UIScene.didDisconnectNotification, object: nil)
    }

    // MARK: - Public window accessors

    @objc public func activeWindow(_ scene: UIScene?) -> SFSDKWindowContainer? {
        let resolvedScene = nonnullScene(scene)
        guard let activeWindow = findActiveWindow(for: resolvedScene),
              let sceneWindows = namedWindows.object(forKey: resolvedScene.session.persistentIdentifier as NSString) else { return nil }
        let enumerator = sceneWindows.objectEnumerator()
        while let container = enumerator?.nextObject() as? SFSDKWindowContainer {
            if container.isEnabled && container.window === activeWindow {
                return container
            }
        }
        return nil
    }

    @objc public func mainWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let resolvedScene = nonnullScene(scene)
        if let existing = containerForWindowKey(kSFMainWindowKey, scene: resolvedScene) {
            return existing
        }
        if let keyWindow = findActiveWindow(for: resolvedScene) {
            lastKeyWindows.setObject(keyWindow, forKey: resolvedScene.session.persistentIdentifier as NSString)
            setMainUIWindow(keyWindow, scene: resolvedScene)
        }
        return containerForWindowKey(kSFMainWindowKey, scene: resolvedScene) ?? SFSDKWindowContainer(name: kSFMainWindowKey)
    }

    @objc public func setMainUIWindow(_ window: UIWindow) {
        setMainUIWindow(window, scene: nil)
    }

    @objc public func setMainUIWindow(_ window: UIWindow, scene: UIScene?) {
        let resolvedScene = nonnullScene(scene)
        let container = SFSDKWindowContainer(window: window, name: kSFMainWindowKey)
        container.windowType = .main
        container.windowDelegate = self
        container.window?.alpha = 1.0
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: kSFMainWindowKey, scene: resolvedScene)
    }

    @objc public func authWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let resolvedScene = nonnullScene(scene)
        if let existing = containerForWindowKey(kSFLoginWindowKey, scene: resolvedScene) {
            setWindowScene(existing, scene: resolvedScene)
            existing.windowLevel = UIWindow.Level(rawValue: mainWindow(resolvedScene).window?.windowLevel.rawValue ?? 0 + SFWindowLevelAuthOffset)
            return existing
        }
        let container = createAuthWindow(for: resolvedScene)
        setWindowScene(container, scene: resolvedScene)
        container.windowLevel = UIWindow.Level(rawValue: (mainWindow(resolvedScene).window?.windowLevel.rawValue ?? 0) + SFWindowLevelAuthOffset)
        return container
    }

    @objc public func snapshotWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let resolvedScene = nonnullScene(scene)
        if let existing = containerForWindowKey(kSFSnapshotWindowKey, scene: resolvedScene) {
            setWindowScene(existing, scene: resolvedScene)
            existing.windowLevel = UIWindow.Level(rawValue: (mainWindow(resolvedScene).window?.windowLevel.rawValue ?? 0) + SFWindowLevelSnapshotOffset)
            return existing
        }
        let container = createSnapshotWindow(for: resolvedScene)
        setWindowScene(container, scene: resolvedScene)
        container.windowLevel = UIWindow.Level(rawValue: (mainWindow(resolvedScene).window?.windowLevel.rawValue ?? 0) + SFWindowLevelSnapshotOffset)
        return container
    }

    @objc public func screenLockWindow() -> SFSDKWindowContainer {
        return screenLockWindow(nil)
    }

    @objc public func screenLockWindow(_ scene: UIScene?) -> SFSDKWindowContainer {
        let resolvedScene = nonnullScene(scene)
        if let existing = containerForWindowKey(kSFScreenLockWindowKey, scene: resolvedScene) {
            setWindowScene(existing, scene: resolvedScene)
            existing.windowLevel = UIWindow.Level(rawValue: (mainWindow(resolvedScene).window?.windowLevel.rawValue ?? 0) + SFWindowLevelScreenLockOffset)
            return existing
        }
        let container = createScreenLockWindow(for: resolvedScene)
        setWindowScene(container, scene: resolvedScene)
        container.windowLevel = UIWindow.Level(rawValue: (mainWindow(resolvedScene).window?.windowLevel.rawValue ?? 0) + SFWindowLevelScreenLockOffset)
        return container
    }

    @objc public func createNewNamedWindow(_ windowName: String) -> SFSDKWindowContainer? {
        return createNewNamedWindow(windowName, scene: nil)
    }

    @objc public func createNewNamedWindow(_ windowName: String, scene: UIScene?) -> SFSDKWindowContainer? {
        let resolvedScene = nonnullScene(scene)
        guard !isReservedName(windowName) else { return nil }
        let container = SFSDKWindowContainer(name: windowName)
        container.windowDelegate = self
        container.windowLevel = .normal
        container.windowType = .other
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: windowName, scene: resolvedScene)
        return container
    }

    @objc public func removeNamedWindow(_ windowName: String) -> Bool {
        return removeNamedWindow(windowName, scene: nil)
    }

    @objc public func removeNamedWindow(_ windowName: String, scene: UIScene?) -> Bool {
        let resolvedScene = nonnullScene(scene)
        guard !isReservedName(windowName) else { return false }
        (namedWindows.object(forKey: resolvedScene.session.persistentIdentifier as NSString))?.removeObject(forKey: windowName as NSString)
        return true
    }

    @objc public func windowWithName(_ name: String) -> SFSDKWindowContainer? {
        return windowWithName(name, scene: nil)
    }

    @objc public func windowWithName(_ name: String, scene: UIScene?) -> SFSDKWindowContainer? {
        let resolvedScene = nonnullScene(scene)
        let container = (namedWindows.object(forKey: resolvedScene.session.persistentIdentifier as NSString))?.object(forKey: name as NSString)
        if let container = container {
            setWindowScene(container, scene: resolvedScene)
        }
        return container
    }

    // MARK: - Delegates

    @objc public func addDelegate(_ delegate: SFSDKWindowManagerDelegate) {
        delegates.add(delegate as AnyObject)
    }

    @objc public func removeDelegate(_ delegate: SFSDKWindowManagerDelegate) {
        delegates.remove(delegate as AnyObject)
    }

    private func enumerateDelegates(_ block: (SFSDKWindowManagerDelegate) -> Void) {
        for obj in delegates.allObjects {
            if let delegate = obj as? SFSDKWindowManagerDelegate {
                block(delegate)
            }
        }
    }

    // MARK: - SFSDKWindowContainerDelegate

    public func presentWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.presentWindow(window, animated: animated, withCompletion: completion) }
            return
        }

        enumerateDelegates { $0.windowManager?(self, willPresentWindow: window) }

        if animated {
            UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
                window.window?.alpha = 1.0
            }.startAnimation()
        }
        makeOpaque(window, completion: completion)
    }

    public func dismissWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.dismissWindow(window, animated: animated, withCompletion: completion) }
            return
        }
        guard window.isEnabled else {
            completion?()
            return
        }

        enumerateDelegates { $0.windowManager?(self, willDismissWindow: window) }

        if animated {
            UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
                window.window?.alpha = 1.0
            }.startAnimation()
        }
        makeTransparent(window, completion: completion)
    }

    // MARK: - Internal / Scene

    @objc public func defaultScene() -> UIScene {
        let connectedScenes = Array(SFApplicationHelper.sharedApplication()?.connectedScenes ?? [])
        for scene in connectedScenes {
            if scene.activationState == .foregroundActive {
                return scene
            } else if scene.activationState == .foregroundInactive {
                return scene
            }
        }
        return connectedScenes.first ?? SFApplicationHelper.sharedApplication()!.connectedScenes.first!
    }

    // MARK: - Private methods

    private func containerForWindowKey(_ key: String, scene: UIScene) -> SFSDKWindowContainer? {
        return (namedWindows.object(forKey: scene.session.persistentIdentifier as NSString))?.object(forKey: key as NSString)
    }

    private func setContainer(_ container: SFSDKWindowContainer, windowKey: String, scene: UIScene) {
        let sceneId = scene.session.persistentIdentifier as NSString
        if let existing = namedWindows.object(forKey: sceneId) {
            existing.setObject(container, forKey: windowKey as NSString)
        } else {
            let sceneWindows = NSMapTable<NSString, SFSDKWindowContainer>.strongToStrongObjects()
            sceneWindows.setObject(container, forKey: windowKey as NSString)
            namedWindows.setObject(sceneWindows, forKey: sceneId)
        }
    }

    private func setWindowScene(_ container: SFSDKWindowContainer, scene: UIScene) {
        let resolvedScene = nonnullScene(scene)
        if container.window?.windowScene !== resolvedScene as? UIWindowScene {
            container.window?.windowScene = resolvedScene as? UIWindowScene
        }
        if let windowScene = container.window?.windowScene {
            container.window?.frame = windowScene.coordinateSpace.bounds
        }
    }

    private func nonnullScene(_ scene: UIScene?) -> UIScene {
        return scene ?? defaultScene()
    }

    private func isReservedName(_ windowName: String) -> Bool {
        return windowName == kSFMainWindowKey || windowName == kSFLoginWindowKey || windowName == kSFScreenLockWindowKey || windowName == kSFSnapshotWindowKey
    }

    private func findActiveWindow(for scene: UIScene) -> UIWindow? {
        let resolvedScene = nonnullScene(scene)
        let sceneId = resolvedScene.session.persistentIdentifier as NSString
        var mainWindow = lastKeyWindows.object(forKey: sceneId)

        if mainWindow == nil, let sceneDelegate = resolvedScene.delegate, sceneDelegate.responds(to: Selector(("window"))) {
            mainWindow = (sceneDelegate as AnyObject).value(forKey: "window") as? UIWindow
        }
        if mainWindow == nil, let appDelegate = SFApplicationHelper.sharedApplication()?.delegate, appDelegate.responds(to: Selector(("window"))) {
            mainWindow = appDelegate.window ?? nil
        }

        if let windowScene = resolvedScene as? UIWindowScene {
            for window in windowScene.windows {
                if window.isKeyWindow {
                    mainWindow = window
                    break
                }
            }
        }
        return mainWindow
    }

    private func createSnapshotWindow(for scene: UIScene?) -> SFSDKWindowContainer {
        let container = SFSDKWindowContainer(name: kSFSnapshotWindowKey)
        container.windowDelegate = self
        container.windowType = .snapshot
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: kSFSnapshotWindowKey, scene: nonnullScene(scene))
        return container
    }

    private func createAuthWindow(for scene: UIScene?) -> SFSDKWindowContainer {
        let container = SFSDKWindowContainer(name: kSFLoginWindowKey)
        container.windowDelegate = self
        container.windowType = .auth
        setContainer(container, windowKey: kSFLoginWindowKey, scene: nonnullScene(scene))
        return container
    }

    private func createScreenLockWindow(for scene: UIScene?) -> SFSDKWindowContainer {
        let container = SFSDKWindowContainer(name: kSFScreenLockWindowKey)
        container.windowDelegate = self
        container.windowType = .screenLock
        container.window?.overrideUserInterfaceStyle = userInterfaceStyle
        setContainer(container, windowKey: kSFScreenLockWindowKey, scene: nonnullScene(scene))
        return container
    }

    private func makeTransparent(_ window: SFSDKWindowContainer, completion: (() -> Void)?) {
        let scene = window.window?.windowScene
        var fallbackWindow = mainWindow(scene)

        if window.isSnapshotWindow || window.isScreenLockWindow {
            if let sceneId = scene?.session.persistentIdentifier as NSString?,
               let last = lastActiveWindows.object(forKey: sceneId) {
                fallbackWindow = last
                lastActiveWindows.removeObject(forKey: sceneId)
            }
        }

        if let sfWindow = window.window as? SFSDKUIWindow {
            sfWindow.disableWindow()
        }

        if !window.isMainWindow, let scene = scene {
            (namedWindows.object(forKey: scene.session.persistentIdentifier as NSString))?.removeObject(forKey: window.windowName as NSString)
        }

        fallbackWindow.window?.makeKeyAndVisible()

        enumerateDelegates { $0.windowManager?(self, didDismissWindow: window) }
        completion?()
    }

    private func makeOpaque(_ window: SFSDKWindowContainer, completion: (() -> Void)?) {
        let scene = window.window?.windowScene

        if window.isSnapshotWindow, let scene = scene {
            if let active = activeWindow(scene), !active.isSnapshotWindow {
                lastActiveWindows.setObject(active, forKey: scene.session.persistentIdentifier as NSString)
            }
        }
        if window.isScreenLockWindow, let scene = scene {
            if let active = activeWindow(scene), !active.isScreenLockWindow {
                lastActiveWindows.setObject(active, forKey: scene.session.persistentIdentifier as NSString)
            }
        }

        guard !window.isEnabled else {
            completion?()
            return
        }

        window.window?.makeKeyAndVisible()
        enumerateDelegates { $0.windowManager?(self, didPresentWindow: window) }
        completion?()
    }

    @objc private func sceneDidDisconnect(_ notification: Notification) {
        guard let scene = notification.object as? UIScene else { return }
        namedWindows.removeObject(forKey: scene.session.persistentIdentifier as NSString)
    }
}
