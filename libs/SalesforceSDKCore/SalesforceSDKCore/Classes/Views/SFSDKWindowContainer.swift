// SFSDKWindowContainer.swift
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

@objc public enum SFSDKWindowType: Int {
    case main
    case auth
    case screenLock
    case snapshot
    case other
}

@objc(SFSDKWindowContainerDelegate)
public protocol SFSDKWindowContainerDelegate: AnyObject {
    @objc optional func presentWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?)
    @objc optional func dismissWindow(_ window: SFSDKWindowContainer, animated: Bool, withCompletion completion: (() -> Void)?)
}

@objc(SFSDKWindowContainer)
@objcMembers
public class SFSDKWindowContainer: NSObject {

    @objc public var window: UIWindow? {
        if _window == nil {
            let scene = SFApplicationHelper.sharedApplication()?.connectedScenes.first as? UIWindowScene
            var bounds = scene?.coordinateSpace.bounds ?? .zero
            #if !os(visionOS)
            if scene == nil {
                bounds = UIScreen.main.bounds
            }
            #endif
            _window = SFSDKUIWindow(frame: bounds, andName: windowName)
            _window?.windowLevel = windowLevel
            if viewController == nil {
                viewController = SFSDKRootController()
            }
        }
        return _window
    }
    private var _window: UIWindow?

    @objc public var windowType: SFSDKWindowType = .other
    @objc public private(set) var windowName: String
    @objc public var windowLevel: UIWindow.Level = .normal {
        didSet { _window?.windowLevel = windowLevel }
    }

    @objc public var viewController: UIViewController? {
        get { return _window?.rootViewController }
        set { _window?.rootViewController = newValue }
    }

    @objc public weak var windowDelegate: SFSDKWindowContainerDelegate?

    @objc public init(window: UIWindow, name windowName: String) {
        self._window = window
        self.windowName = windowName
        super.init()
    }

    @objc public init(name windowName: String) {
        self.windowName = windowName
        super.init()
    }

    @objc public var isEnabled: Bool {
        #if os(visionOS)
        return (window?.rootViewController?.view.alpha == 1.0) && !(window?.isHidden ?? true)
        #else
        return (window?.alpha == 1.0) && !(window?.isHidden ?? true)
        #endif
    }

    @objc public func presentWindow() {
        presentWindow(animated: false, withCompletion: nil)
    }

    @objc public func presentWindow(animated: Bool, withCompletion completion: (() -> Void)?) {
        windowDelegate?.presentWindow?(self, animated: animated, withCompletion: completion)
    }

    @objc public func dismissWindow() {
        dismissWindow(animated: false, withCompletion: nil)
    }

    @objc public func dismissWindow(animated: Bool, withCompletion completion: (() -> Void)?) {
        guard isEnabled else { return }
        windowDelegate?.dismissWindow?(self, animated: animated, withCompletion: completion)
    }

    @objc public var isMainWindow: Bool {
        return windowType == .main
    }

    @objc public var isAuthWindow: Bool {
        return windowType == .auth
    }

    @objc public var isSnapshotWindow: Bool {
        return windowType == .snapshot
    }

    @objc public var isScreenLockWindow: Bool {
        return windowType == .screenLock
    }

    @objc public func topViewController() -> UIViewController? {
        guard let root = _window?.rootViewController else { return nil }
        return SFSDKWindowContainer.topViewController(withRootViewController: root)
    }

    @objc public class func topViewController(withRootViewController viewController: UIViewController?) -> UIViewController? {
        guard let viewController = viewController else { return nil }
        if let tabBarController = viewController as? UITabBarController {
            return topViewController(withRootViewController: tabBarController.selectedViewController)
        } else if let navController = viewController as? UINavigationController {
            return topViewController(withRootViewController: navController.visibleViewController)
        } else if let presented = viewController.presentedViewController, !presented.isBeingDismissed {
            return topViewController(withRootViewController: presented)
        } else {
            for view in viewController.view.subviews {
                if let subVC = view.next as? UIViewController {
                    if let presented = subVC.presentedViewController, !presented.isBeingDismissed {
                        return topViewController(withRootViewController: presented)
                    }
                }
            }
            return viewController
        }
    }
}
