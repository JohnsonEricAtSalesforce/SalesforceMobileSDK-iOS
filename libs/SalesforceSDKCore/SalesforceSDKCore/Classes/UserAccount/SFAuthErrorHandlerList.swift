/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins

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

/**
 Manages the authentication handler filter list, for processing authentication errors.  Note that
 order of entries is important: the list will be processed serially, starting with the first item
 and ending with the last.
 */
@objc(SFAuthErrorHandlerList)
public class AuthErrorHandlerList: NSObject {

    /**
     The mutable array/list of error handler objects.
     */
    private var authHandlerMutableArray: NSMutableArray

    /**
     A readonly copy of the array of authentication error handlers.
     */
    @objc public var authHandlerArray: [Any] {
        return self.authHandlerMutableArray as NSArray as! [Any]
    }

    // MARK: - Initialization

    public override init() {
        self.authHandlerMutableArray = NSMutableArray()
        super.init()
    }

    // MARK: - Public Methods

    /**
     Adds an authentication error handler to the end of the filter list.  Note: Error handler
     names must be unique within the list, so if an error handler already exists with the
     given name, it will be removed before adding the new handler.
     - Parameter errorHandler: The error handler to add to the list.
     */
    @objc(addAuthErrorHandler:)
    public func addAuthErrorHandler(_ errorHandler: AuthErrorHandler) {
        self.addAuthErrorHandler(errorHandler, at: self.authHandlerMutableArray.count)
    }

    /**
     Adds an authentication error handler at a specific index in the list.  Note: Error handler
     names must be unique within the list, so if an error handler already exists with the
     given name, it will be removed before adding the new handler.
     - Parameter errorHandler: The error handler to add to the list.
     - Parameter index: The index at which to add the error handler.
     */
    @objc(addAuthErrorHandler:atIndex:)
    public func addAuthErrorHandler(_ errorHandler: AuthErrorHandler, at index: Int) {
        if let existingHandler = self.retrieveAuthErrorHandler(withName: errorHandler.name) {
            SFSDKCoreLogger.w(type(of: self), message: "Existing auth error handler with name '\(existingHandler.name)' will be removed.")
            self.removeAuthErrorHandler(existingHandler)
        }
        self.authHandlerMutableArray.insert(errorHandler, at: index)
    }

    /**
     Removes the error handler with the given name from the list.  If no error handler exists
     in the list with the name, no action is taken.
     - Parameter errorHandlerName: The name of the error handler to remove.
     */
    @objc(removeAuthErrorHandlerWithName:)
    public func removeAuthErrorHandler(withName errorHandlerName: String) {
        if let existingHandler = self.retrieveAuthErrorHandler(withName: errorHandlerName) {
            self.removeAuthErrorHandler(existingHandler)
        } else {
            SFSDKCoreLogger.w(type(of: self), message: "Auth error handler with name '\(errorHandlerName)' not found.  No action taken.")
        }
    }

    /**
     Removes the given error handler from the list.  If the error handler cannot be found, no
     action is taken.
     - Parameter errorHandler: The error handler to remove.
     */
    @objc(removeAuthErrorHandler:)
    public func removeAuthErrorHandler(_ errorHandler: AuthErrorHandler) {
        self.authHandlerMutableArray.remove(errorHandler)
    }

    /**
     Determines whether the given error handler is in the list.
     - Parameter errorHandler: The error handler to look for in the list.
     - Returns: true if the error handler is in the list, false otherwise.
     */
    @objc(authErrorHandlerInList:)
    public func authErrorHandlerInList(_ errorHandler: AuthErrorHandler) -> Bool {
        let predicate = NSPredicate(format: "SELF == %@", errorHandler)
        let resultArray = (self.authHandlerMutableArray as NSArray).filtered(using: predicate)
        return resultArray.count > 0
    }

    // MARK: - Private Methods

    /**
     Retrieves an error handler, based on its name.
     - Parameter name: The name of the error handler to retrieve from the list.
     - Returns: The error handler, or nil if no error handler with the given name was found.
     */
    private func retrieveAuthErrorHandler(withName name: String) -> AuthErrorHandler? {
        let predicate = NSPredicate(format: "SELF.name MATCHES %@", name)
        let resultArray = (self.authHandlerMutableArray as NSArray).filtered(using: predicate)
        if resultArray.count > 0 {
            return resultArray[0] as? AuthErrorHandler
        } else {
            return nil
        }
    }
}
