//
//  SFSDKKeyValueEncryptedFileStoreTests.swift
//  SalesforceSDKCoreTests
//
//  Created by Brianna Birman on 6/23/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore

class SFSDKKeyValueEncryptedFileStoreTests: XCTestCase {

    private var userAccount: UserAccount?

    override func setUp() {
        super.setUp()
        guard let credentials = OAuthCredentials.credentials(identifier: "keyvalue-test", clientId: "fakeClientIdForTesting", encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        userAccount = UserAccount(credentials: credentials)
        userAccount?.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0IAC")
    }

    override func tearDown() {
        var error: Error?
        let globalPathStr = globalPath()
        if FileManager.default.fileExists(atPath: globalPathStr) {
            do {
                try FileManager.default.removeItem(atPath: globalPathStr)
            } catch let e {
                error = e
            }
            XCTAssertNil(error, "Error removing item at path '\(globalPathStr)': \(String(describing: error))")
        }
        if let user = userAccount {
            let userPathStr = userPath(user)
            if FileManager.default.fileExists(atPath: userPathStr) {
                do {
                    try FileManager.default.removeItem(atPath: userPathStr)
                } catch let e {
                    error = e
                }
                XCTAssertNil(error, "Error removing item at path '\(userPathStr)': \(String(describing: error))")
            }
        }
        userAccount = nil
        super.tearDown()
    }

    // MARK: - Store management

    func testGlobalStoreUsesSameStore() {
        let storeName = "test_global_uses_same_store"

        guard let store = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName) else {
            XCTFail("Failed to create global store")
            return
        }
        store["key1"] = "value1"
        store["key2"] = "value2"
        XCTAssertEqual(store.count(), 2)

        guard let storeAgain = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName) else {
            XCTFail("Failed to get global store again")
            return
        }
        XCTAssertEqual(storeAgain.count(), 2)
        XCTAssertEqual(storeAgain["key1"], "value1")
        XCTAssertEqual(storeAgain["key2"], "value2")
    }

    func testUserStoreUsesSameStore() {
        guard let user = userAccount else { XCTFail("No user account"); return }
        let storeName = "test_user_uses_same_store"
        guard let store = KeyValueEncryptedFileStore.shared(withName: storeName, forUserAccount: user) else {
            XCTFail("Failed to create user store")
            return
        }
        store["user_key1"] = "user_value1"
        store["user_key2"] = "user_value2"
        XCTAssertEqual(store.count(), 2)

        guard let storeAgain = KeyValueEncryptedFileStore.shared(withName: storeName, forUserAccount: user) else {
            XCTFail("Failed to get user store again")
            return
        }
        XCTAssertEqual(storeAgain.count(), 2)
        XCTAssertEqual(storeAgain["user_key1"], "user_value1")
        XCTAssertEqual(storeAgain["user_key2"], "user_value2")
    }

    func testUserStores() {
        guard let user = userAccount else { XCTFail("No user account"); return }
        let storeName1 = "user_store_1"
        let storeName2 = "user_store_2"
        let storeName3 = "user_store_3"

        let store1 = KeyValueEncryptedFileStore.shared(withName: storeName1, forUserAccount: user)
        let store2 = KeyValueEncryptedFileStore.shared(withName: storeName2, forUserAccount: user)
        let store3 = KeyValueEncryptedFileStore.shared(withName: storeName3, forUserAccount: user)

        XCTAssertNotNil(store1)
        XCTAssertNotNil(store2)
        XCTAssertNotNil(store3)

        // Verify stores exist on disk
        let storeDirectories = try? FileManager.default.contentsOfDirectory(atPath: userPath(user))
        XCTAssertEqual(storeDirectories?.count, 3, "Number of directories don't match number of stores created")

        // Verify names
        let storeNames = KeyValueEncryptedFileStore.allNames(forUserAccount: user)
        XCTAssertEqual(storeNames.count, 3)
        XCTAssertTrue(storeNames.contains(storeName1))
        XCTAssertTrue(storeNames.contains(storeName2))
        XCTAssertTrue(storeNames.contains(storeName3))

        KeyValueEncryptedFileStore.removeShared(withName: storeName2, forUserAccount: user)
        XCTAssertEqual(KeyValueEncryptedFileStore.allNames(forUserAccount: user).count, 2)

        KeyValueEncryptedFileStore.removeAll(forUserAccount: user)
        XCTAssertEqual(KeyValueEncryptedFileStore.allNames(forUserAccount: user).count, 0)
    }

    func testGlobalStores() {
        let storeName1 = "global_store_1"
        let storeName2 = "global_store_2"
        let storeName3 = "global_store_3"

        let store1 = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName1)
        let store2 = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName2)
        let store3 = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName3)

        XCTAssertNotNil(store1)
        XCTAssertNotNil(store2)
        XCTAssertNotNil(store3)

        // Verify stores exist on disk
        let storeDirectories = try? FileManager.default.contentsOfDirectory(atPath: globalPath())
        XCTAssertEqual(storeDirectories?.count, 3, "Number of directories don't match number of stores created")

        // Verify names
        let storeNames = KeyValueEncryptedFileStore.allGlobalNames()
        XCTAssertEqual(storeNames.count, 3)
        XCTAssertTrue(storeNames.contains(storeName1))
        XCTAssertTrue(storeNames.contains(storeName2))
        XCTAssertTrue(storeNames.contains(storeName3))

        KeyValueEncryptedFileStore.removeSharedGlobal(withName: storeName2)
        XCTAssertEqual(KeyValueEncryptedFileStore.allGlobalNames().count, 2)

        KeyValueEncryptedFileStore.removeAllGlobal()
        XCTAssertEqual(KeyValueEncryptedFileStore.allGlobalNames().count, 0)
    }

    // MARK: - Store operations

    func testStoreVersion() {
        guard let store = createStore(withName: "new_store") else {
            XCTFail("Failed to create store")
            return
        }
        XCTAssertEqual(store.storeVersion, 2)
    }

    func testV1StoreVersion() {
        guard let store = createV1Store(withName: "legacy_store") else {
            XCTFail("Failed to create v1 store")
            return
        }
        XCTAssertEqual(store.storeVersion, 1)
    }

    func testStoreWithUnreadableVersion() {
        guard let store = createStore(withName: "new_store") else {
            XCTFail("Failed to create store")
            return
        }
        let versionFileURL = store.directory.appendingPathComponent("version")
        let badVersionData = "bad_version_data".data(using: .utf8)
        try? badVersionData?.write(to: versionFileURL)
        let reopenedStore = createStore(withName: "new_store")
        XCTAssertNil(reopenedStore)
    }

    func testIsValidName() {
        XCTAssertTrue(KeyValueEncryptedFileStore.isValidName("123456789"))
        XCTAssertTrue(KeyValueEncryptedFileStore.isValidName("test_store"))

        let longName = "this_is_a_string_for_a_test_store_name_that_is_going_to_be_too_long_and_should_not_be_considered_valid"
        XCTAssertFalse(KeyValueEncryptedFileStore.isValidName(longName))
        XCTAssertFalse(KeyValueEncryptedFileStore.isValidName(""))
        XCTAssertFalse(KeyValueEncryptedFileStore.isValidName("test store"))
        XCTAssertFalse(KeyValueEncryptedFileStore.isValidName("test.store"))
        XCTAssertFalse(KeyValueEncryptedFileStore.isValidName("test/store"))
    }

    func testStoreName() {
        let storeName = "test_store_name"
        guard let store = createStore(withName: storeName) else {
            XCTFail("Failed to create store")
            return
        }
        XCTAssertEqual(store.name, storeName, "Store names don't match")
    }

    func testBadStoreName() {
        let store = createStore(withName: "")
        XCTAssertNil(store)
    }

    func testBadDirectory() {
        let store = KeyValueEncryptedFileStore(parentDirectory: "", name: "test_bad_directory")
        XCTAssertNil(store)
    }

    func testSaveReadRemoveEntries() {
        let entryCount = 20
        guard let store = createStore(withName: "test_entries") else {
            XCTFail("Failed to create store")
            return
        }
        for i in 0..<entryCount {
            let key = "key\(i)"
            let value = "value\(i)"
            let saveSuccess = store.saveValue(value, forKey: key)
            XCTAssertTrue(saveSuccess)
        }

        for i in 0..<entryCount {
            XCTAssertEqual(store.count(), entryCount - i)
            let key = "key\(i)"
            let expectedValue = "value\(i)"
            let value = store[key]
            XCTAssertEqual(expectedValue, value)
            let deleteSuccess = store.removeValue(forKey: key)
            XCTAssertTrue(deleteSuccess)
            XCTAssertEqual(store.count(), entryCount - i - 1)
        }
    }

    func testSubscriptSaveRemove() {
        guard let store = createStore(withName: "test_subscript_save_remove") else {
            XCTFail("Failed to create store")
            return
        }
        let key = "key"
        let value = "value"
        store[key] = value
        XCTAssertEqual(value, store[key])
        store[key] = nil
        XCTAssertNil(store[key])
    }

    func testRemoveAll() {
        let entryCount = 20
        guard let store = createStore(withName: "test_remove_all") else {
            XCTFail("Failed to create store")
            return
        }
        for i in 0..<entryCount {
            let key = "key\(i)"
            let value = "value\(i)"
            let saveSuccess = store.saveValue(value, forKey: key)
            XCTAssertTrue(saveSuccess)
        }
        XCTAssertEqual(store.count(), entryCount)
        store.removeAll()
        XCTAssertEqual(store.count(), 0)
    }

    func testAllKeys() {
        guard let store = createStore(withName: "test_all_keys") else {
            XCTFail("Failed to create store")
            return
        }
        let entryCount = 12
        var expectedKeys = [String]()
        for i in 0..<entryCount {
            let key = "key\(i)"
            let value = "value\(i)"
            let saveSuccess = store.saveValue(value, forKey: key)
            XCTAssertTrue(saveSuccess)
            expectedKeys.append(key)
        }
        guard let keys = store.allKeys() else {
            XCTFail("allKeys returned nil")
            return
        }
        let sortedKeys = keys.sorted()
        let sortedExpectedKeys = expectedKeys.sorted()
        XCTAssertEqual(sortedKeys, sortedExpectedKeys)
    }

    func testV1StoreAllKeys() {
        guard let store = createV1Store(withName: "test_all_keys_v1") else {
            XCTFail("Failed to create v1 store")
            return
        }
        let entryCount = 12
        for i in 0..<entryCount {
            let key = "key\(i)"
            let value = "value\(i)"
            let saveSuccess = store.saveValue(value, forKey: key)
            XCTAssertTrue(saveSuccess)
        }
        XCTAssertNil(store.allKeys())
    }

    func testOverwriteValue() {
        guard let store = createStore(withName: "test_overwrite_value") else {
            XCTFail("Failed to create store")
            return
        }
        let key = "overwrite_key"
        let value = "value"
        let newValue = "new_value"

        store.saveValue(value, forKey: key)
        var storeValue = store[key]
        XCTAssertEqual(storeValue, value)
        store.saveValue(newValue, forKey: key)
        storeValue = store[key]
        XCTAssertEqual(storeValue, newValue)
    }

    func testIsEmpty() {
        guard let store = createStore(withName: "test_is_empty") else {
            XCTFail("Failed to create store")
            return
        }
        XCTAssertTrue(store.isEmpty())
        store.saveValue("value", forKey: "key")
        XCTAssertFalse(store.isEmpty())
    }

    func testStoreEncryption() {
        guard let store = createStore(withName: "test_store_encryption") else {
            XCTFail("Failed to create store")
            return
        }
        let value = "value"
        store.saveValue(value, forKey: "key")

        // Read value directly from file, shouldn't be the same as the unencrypted value
        let files = try? FileManager.default.contentsOfDirectory(atPath: store.directory.path)
        XCTAssertNil(nil, "Error getting contents should not happen")
        XCTAssertEqual(files?.count, 4, "Unexpected number of files in store")
        guard let firstFile = files?.first else { return }
        let valuePath = store.directory.appendingPathComponent(firstFile).path
        let fileData = FileManager.default.contents(atPath: valuePath)
        let valueData = value.data(using: .utf8)
        XCTAssertNotEqual(fileData, valueData)
    }

    func testInvalidKey() {
        guard let store = createStore(withName: "test_invalid_key") else {
            XCTFail("Failed to create store")
            return
        }
        XCTAssertFalse(store.saveValue("value", forKey: ""))
    }

    func testExistingFile() {
        let fileName = "existing_file"
        SFDirectoryManager.ensureDirectoryExists(globalPath(), error: nil)
        let filePath = (globalPath() as NSString).appendingPathComponent(fileName)

        // Create file
        let fileContents = "existing_file_contents"
        try? fileContents.write(toFile: filePath, atomically: false, encoding: .utf8)

        // Shouldn't be able to create store at the same location as the existing file
        let store = createStore(withName: fileName)
        XCTAssertNil(store)
    }

    func testBinaryStorage() {
        guard let store = createStore(withName: "test_binary_storage") else {
            XCTFail("Failed to create store")
            return
        }

        // Saving binary data to key value store
        let sampleData = randomData()
        store.saveData(sampleData, forKey: "key")

        // Retrieving binary back from key value store
        let savedData = store.readData(key: "key")

        // Comparing bytes
        XCTAssertEqual(savedData, sampleData, "Retrieved data different from original data")
    }

    // MARK: - Helpers

    private func randomData() -> Data {
        let size = 2048
        var data = Data(capacity: size)
        for _ in 0..<(size / 4) {
            var randomBits = arc4random()
            data.append(Data(bytes: &randomBits, count: 4))
        }
        return data
    }

    private func globalPath() -> String {
        return SFDirectoryManager.shared.globalDirectory(ofType: .documentDirectory, components: ["key_value_stores"]) ?? ""
    }

    private func userPath(_ user: UserAccount) -> String {
        return SFDirectoryManager.shared.directory(forUser: user, type: .documentDirectory, components: ["key_value_stores"]) ?? ""
    }

    private func createStore(withName name: String) -> KeyValueEncryptedFileStore? {
        let parentDirectory = globalPath()
        return KeyValueEncryptedFileStore(parentDirectory: parentDirectory, name: name)
    }

    private func createV1Store(withName name: String) -> KeyValueEncryptedFileStore? {
        guard let store = createStore(withName: name) else { return nil }
        let versionFileURL = store.directory.appendingPathComponent("version")
        do {
            try FileManager.default.removeItem(at: versionFileURL)
        } catch {
            XCTFail("Error deleting '\(store.directory.path)': \(error)")
        }
        return createStore(withName: name)
    }
}
