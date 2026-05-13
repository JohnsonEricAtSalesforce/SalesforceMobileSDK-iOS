/*
 SFSDKLoginHost.swift
 SalesforceSDKCore

 Created by Kunal Chitalia on 1/22/16.
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

/// Class that encapsulates the information about a login host.
@objc(SFSDKLoginHost)
@objcMembers
public class SalesforceLoginHost: NSObject {

    /// The name of the login host.
    public var name: String

    /// The server address of the login host.
    public var host: String

    /// Indicates whether this login host can be deleted.
    public private(set) var isDeletable: Bool

    private override init() {
        self.name = ""
        self.host = ""
        self.isDeletable = false
        super.init()
    }

    /// Returns a new login host instance with the specified parameters.
    /// - Parameters:
    ///   - name: Name of the login host.
    ///   - host: Server address of the login host.
    ///   - deletable: true if the host can be deleted.
    /// - Returns: A new SalesforceLoginHost instance.
    @objc(hostWithName:host:deletable:)
    public static func host(withName name: String?, host: String?, deletable: Bool) -> SalesforceLoginHost {
        let loginHost = SalesforceLoginHost()

        loginHost.name = name ?? ""  // Ensure name is not nil.
        if let host = host, host.hasSuffix("/"), host.count > 1 {
            loginHost.host = String(host.dropLast())
        } else {
            loginHost.host = host ?? ""
        }
        loginHost.isDeletable = deletable

        return loginHost
    }
}
