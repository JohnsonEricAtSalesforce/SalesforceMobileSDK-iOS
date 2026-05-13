/*
 SFSDKAlertView.swift
 SalesforceSDKCore

 Created by Raj Rao on 10/01/17.

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

@objc(SFSDKAlertView)
@objcMembers
public class SFSDKAlertView: NSObject {

    public let controller: UIAlertController
    public weak var window: SFSDKWindowContainer?
    private let message: AlertMessage

    public init(message: AlertMessage, window: SFSDKWindowContainer) {
        self.message = message
        self.window = window
        self.controller = UIAlertController(
            title: message.alertTitle,
            message: message.alertMessage,
            preferredStyle: .alert
        )
        super.init()
    }

    public func presentViewController(_ animated: Bool, completion: (() -> Void)?) {
        if !message.actionOneTitle.isEmpty {
            let actionOneButton = UIAlertAction(title: message.actionOneTitle, style: .default) { [weak self] _ in
                self?.message.actionOneCompletion()
            }
            controller.addAction(actionOneButton)
        }

        if !message.actionTwoTitle.isEmpty {
            let actionTwoButton = UIAlertAction(title: message.actionTwoTitle, style: .default) { [weak self] _ in
                self?.message.actionTwoCompletion()
            }
            controller.addAction(actionTwoButton)
        }

        window?.presentWindowAnimated(false) { [weak self] in
            guard let self = self, let window = self.window else { return }
            var controller = window.viewController
            if let presentedVC = window.viewController?.presentedViewController,
               !presentedVC.isBeingDismissed {
                controller = presentedVC
            }
            controller?.present(self.controller, animated: animated, completion: completion)
        }
    }

    private func blankViewController() -> UIViewController {
        let blankViewController = UIViewController()
        blankViewController.view.backgroundColor = .clear
        return blankViewController
    }
}
