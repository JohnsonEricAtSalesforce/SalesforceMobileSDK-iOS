/*
 SFSDKURLHandlerManager.swift
 SalesforceSDKCore

 Created by Raj Rao on 8/28/17.

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

@objc(SFSDKURLHandlerManager)
public class SFSDKURLHandlerManager: NSObject {

    private var handlerList: [SFSDKURLHandler]

    public override init() {
        self.handlerList = []
        super.init()

        handlerList.append(SFSDKAdvancedAuthURLHandler())
        handlerList.append(SFSDKIDPRequestHandler())
        handlerList.append(SFSDKSPLoginResponseHandler())
        handlerList.append(SFSDKIDPErrorHandler())
        handlerList.append(SFSDKIDPLoginRequestHandler())
        handlerList.append(SFSDKIDPAuthCodeLoginRequestHandler())
    }

    @objc
    public func canHandleRequest(_ url: URL, options: [AnyHashable: Any]?) -> Bool {
        var result = false

        for handler in handlerList {
            result = handler.canHandleRequest(url, options: options)
            if result {
                break
            }
        }

        return result
    }

    @objc
    public func processRequest(_ url: URL,
                               options: [AnyHashable: Any]?,
                               completion: SFUserAccountManagerSuccessCallbackBlock?,
                               failure: SFUserAccountManagerFailureCallbackBlock?) -> Bool {
        var result = false

        for handler in handlerList {
            if handler.canHandleRequest(url, options: options) {
                if handler.responds(to: #selector(SFSDKURLHandler.processRequest(_:options:completion:failure:))) {
                    result = handler.processRequest?(url, options: options, completion: completion, failure: failure) ?? false
                } else {
                    result = handler.processRequest(url, options: options)
                }
            }
            if result {
                break
            }
        }

        return result
    }

    @objc
    public static let sharedInstance: SFSDKURLHandlerManager = {
        return SFSDKURLHandlerManager()
    }()
}
