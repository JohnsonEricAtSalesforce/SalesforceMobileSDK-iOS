// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
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

import Foundation

/// Data object representing a symmetric encryption key, with a key value and initialization vector.
@objc(SFEncryptionKey)
@objcMembers
public class SFEncryptionKey: NSObject {

    /// Key component of the object.
    public var key: Data?

    /// Initialization vector component of the object.
    public var initializationVector: Data?

    /// The base64 representation of the key data.
    public var keyAsString: String? {
        return key?.base64EncodedString(options: [])
    }

    /// The base64 representation of the initialization vector data.
    public var initializationVectorAsString: String? {
        return initializationVector?.base64EncodedString(options: [])
    }

    /// Designated initializer.
    /// - Parameters:
    ///   - keyData: The key component, represented as Data.
    ///   - iv: The initialization vector, represented as Data.
    public init(data keyData: Data, initializationVector iv: Data?) {
        self.key = keyData
        self.initializationVector = iv
        super.init()
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SFEncryptionKey else { return false }
        if other === self { return true }
        return key == other.key && initializationVector == other.initializationVector
    }

    public override var hash: Int {
        var result = 43
        result = 43 &* result &+ (key?.hashValue ?? 0)
        result = 43 &* result &+ (initializationVector?.hashValue ?? 0)
        return result
    }
}
