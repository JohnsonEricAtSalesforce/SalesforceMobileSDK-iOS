/*
 SFSDKWindowContainer.swift
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

@objc public enum SFSDKWindowType: Int {
    case main
    case auth
    case screenLock
    case snapshot
    case other
}

@objc public protocol SFSDKWindowContainerDelegate: AnyObject {

    /// Called when the window has to be enabled
    /// - Parameters:
    ///   - window: The window
    ///   - animated: Whether to animate the presentation
    ///   - completion: Completion block
    @objc optional func presentWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?)

    /// Called when the window has to be disabled
    /// - Parameters:
    ///   - window: The window
    ///   - animated: Whether to animate the dismissal
    ///   - completion: Completion block
    @objc optional func dismissWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?)
}

@objc(SFSDKWindowContainer)
@objcMembers
public class SFSDKWindowContainer: NSObject {

    /// Underlying Window that is wrapped by this container
    public var window: UIWindow? {
        get {
            if _window == nil {
                let scene = SFApplicationHelper.sharedApplication()?.connectedScenes.first as? UIWindowScene
                var bounds: CGRect
                if let scene = scene {
                    bounds = scene.coordinateSpace.bounds
                } else {
                    #if !targetEnvironment(simulator) && !os(visionOS)
                    bounds = UIScreen.main.bounds
                    #else
                    bounds = .zero
                    #endif
                }

                _window = SFSDKUIWindow(frame: bounds, andName: windowName)
                _window?.windowLevel = windowLevel
                if viewController == nil {
                    viewController = SFSDKRootController()
                }
            }
            return _window
        }
        set {
            _window = newValue
        }
    }
    private var _window: UIWindow?

    /// SFSDKWindowType for the window
    public var windowType: SFSDKWindowType = .other

    /// SFSDKWindowType windowName
    public private(set) var windowName: String

    public var windowLevel: UIWindow.Level = .normal {
        didSet {
            _window?.windowLevel = windowLevel
        }
    }

    /// UIViewController viewController
    public var viewController: UIViewController? {
        get {
            return _window?.rootViewController
        }
        set {
            if let window = _window {
                window.rootViewController = newValue
            }
        }
    }

    /// SFSDKWindowContainerDelegate window Delegate
    public weak var windowDelegate: SFSDKWindowContainerDelegate?

    /// Create an instance of a Window
    /// - Parameters:
    ///   - window: An instance of UIWindow
    ///   - windowName: key for the UIWindow
    public init(window: UIWindow, name windowName: String) {
        self.windowName = windowName
        self._window = window
        super.init()
    }

    /// Create an instance of a Window
    /// - Parameter windowName: key for the UIWindow
    public init(name windowName: String) {
        self.windowName = windowName
        super.init()
    }

    /// Returns true if window alpha is set to 1.0
    public func isEnabled() -> Bool {
        guard let window = window else { return false }
        #if os(visionOS)
        return window.rootViewController?.view.alpha == 1.0 && !window.isHidden
        #else
        return window.alpha == 1.0 && !window.isHidden
        #endif
    }

    /// Make window visible, set alpha to 1.0
    public func presentWindow() {
        presentWindowAnimated(false, withCompletion: nil)
    }

    /// Make window visible, set alpha to 1.0 invoke completion block
    /// - Parameters:
    ///   - animated: Whether to animate the presentation
    ///   - completion: Completion block
    public func presentWindowAnimated(_ animated: Bool, withCompletion completion: (() -> Void)?) {
        windowDelegate?.presentWindow?(self, animated: animated, withCompletion: completion)
    }

    /// Make window invisible
    public func dismissWindow() {
        dismissWindowAnimated(false, withCompletion: nil)
    }

    /// Make window visible
    /// - Parameters:
    ///   - animated: Whether to animate the dismissal
    ///   - completion: Completion block
    public func dismissWindowAnimated(_ animated: Bool, withCompletion completion: (() -> Void)?) {
        if isEnabled() {
            windowDelegate?.dismissWindow?(self, animated: animated, withCompletion: completion)
        }
    }

    /// Convenience API returns true if the SFSDKWindowType is main
    /// - Returns: true if this is the main Window
    public func isMainWindow() -> Bool {
        return windowType == .main
    }

    /// Convenience API returns true if the SFSDKWindowType is auth
    /// - Returns: true if this is the auth Window
    public func isAuthWindow() -> Bool {
        return windowType == .auth
    }

    /// Convenience API returns true if the SFSDKWindowType is snapshot
    /// - Returns: true if this is the snapshot Window
    public func isSnapshotWindow() -> Bool {
        return windowType == .snapshot
    }

    /// Convenience API returns true if the SFSDKWindowType is screen lock
    /// - Returns: true if this is the screen lock Window
    public func isScreenLockWindow() -> Bool {
        return windowType == .screenLock
    }

    /// Tries to return top view controller of this window
    /// - Returns: The top view controller
    public func topViewController() -> UIViewController? {
        return SFSDKWindowContainer.topViewController(withRootViewController: _window?.rootViewController)
    }

    /// Tries to return top view controller given a rootViewController
    /// - Parameter viewController: The root view controller
    /// - Returns: The top view controller
    public static func topViewController(withRootViewController viewController: UIViewController?) -> UIViewController? {
        guard let viewController = viewController else { return nil }

        if let tabBarController = viewController as? UITabBarController {
            return topViewController(withRootViewController: tabBarController.selectedViewController)
        } else if let navController = viewController as? UINavigationController {
            return topViewController(withRootViewController: navController.visibleViewController)
        } else if let presentedViewController = viewController.presentedViewController,
                  !presentedViewController.isBeingDismissed {
            return topViewController(withRootViewController: presentedViewController)
        } else {
            for view in viewController.view.subviews {
                if let subViewController = view.next as? UIViewController {
                    if let presentedVC = subViewController.presentedViewController,
                       !presentedVC.isBeingDismissed {
                        return topViewController(withRootViewController: presentedVC)
                    }
                }
            }
            return viewController
        }
    }
}
