/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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
 Cache for smart sql to sql conversions
 */
@objc(SFSmartSqlCache)
@objcMembers
public class SmartSqlCache: NSObject, NSCacheDelegate {

    private let cache: NSCache<NSString, NSString>
    private var keys: NSMutableSet

    @objc(initWithCountLimit:)
    public init(countLimit: UInt) {
        self.cache = NSCache<NSString, NSString>()
        self.cache.countLimit = Int(countLimit)
        self.keys = NSMutableSet()
        super.init()
        self.cache.delegate = self
    }

    @objc(setSql:forSmartSql:)
    public func setSql(_ sql: String, forSmartSql smartSql: String) {
        cache.setObject(sql as NSString, forKey: smartSql as NSString)
        keys.add(smartSql)
    }

    @objc(sqlForSmartSql:)
    public func sql(forSmartSql smartSql: String) -> String? {
        return cache.object(forKey: smartSql as NSString) as String?
    }

    @objc(removeEntriesForSoup:)
    public func removeEntries(forSoup soupName: String) {
        let soupRef = "{\(soupName)}"
        var keysToRemove: [String] = []
        for smartSql in keys.allObjects as! [String] {
            if smartSql.range(of: soupRef) != nil {
                keysToRemove.append(smartSql)
            }
        }
        for keyToRemove in keysToRemove {
            cache.removeObject(forKey: keyToRemove as NSString)
            keys.remove(keyToRemove)
        }
    }

    // MARK: - NSCacheDelegate methods

    @objc(cache:willEvictObject:)
    public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        keys.remove(obj)
    }
}
