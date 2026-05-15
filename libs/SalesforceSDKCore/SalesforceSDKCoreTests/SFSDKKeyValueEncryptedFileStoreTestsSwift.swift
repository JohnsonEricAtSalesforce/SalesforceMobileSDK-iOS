/*
 Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.

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

import XCTest
@testable import SalesforceSDKCore

final class KeyValueEncryptedFileStoreTestsSwift: XCTestCase {

    private var userAccount: SFUserAccount!

    override func setUp() {
        super.setUp()
        let credentials = SFOAuthCredentials(identifier: "keyvalue-test", clientId: "fakeClientIdForTesting", encrypted: true)
        userAccount = SFUserAccount(credentials: credentials)
        userAccount.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0IAC")
    }

    override func tearDown() {
        var error: Error?
        if FileManager.default.fileExists(atPath: globalPath()) {
            do {
                try FileManager.default.removeItem(atPath: globalPath())
            } catch let e {
                error = e
                XCTAssertNil(error, "Error removing item at path '\(globalPath())': \(String(describing: error))")
            }
        }
        if FileManager.default.fileExists(atPath: userPath(userAccount)) {
            do {
                try FileManager.default.removeItem(atPath: userPath(userAccount))
            } catch let e {
                error = e
                XCTAssertNil(error, "Error removing item at path '\(userPath(userAccount))': \(String(describing: error))")
            }
        }
        userAccount = nil
        super.tearDown()
    }

    // MARK: - Store management

    func testGlobalStoreUsesSameStore() {
        let storeName = "test_global_uses_same_store"

        let store = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName)
        store?["key1"] = "value1"
        store?["key2"] = "value2"
        XCTAssertEqual(store?.count(), 2)

        let storeAgain = KeyValueEncryptedFileStore.sharedGlobal(withName: storeName)
        XCTAssertEqual(storeAgain?.count(), 2)
        XCTAssertEqual(storeAgain?["key1"], "value1")
        XCTAssertEqual(storeAgain?["key2"], "value2")
    }

    func testUserStoreUsesSameStore() {
        let storeName = "test_user_uses_same_store"
        let store = KeyValueEncryptedFileStore.shared(withName: storeName, forUserAccount: userAccount)
        store?["user_key1"] = "user_value1"
        store?["user_key2"] = "user_value2"
        XCTAssertEqual(store?.count(), 2)

        let storeAgain = KeyValueEncryptedFileStore.shared(withName: storeName, forUserAccount: userAccount)
        XCTAssertEqual(storeAgain?.count(), 2)
        XCTAssertEqual(storeAgain?["user_key1"], "user_value1")
        XCTAssertEqual(storeAgain?["user_key2"], "user_value2")
    }

    func testUserStores() {
        let storeName1 = "user_store_1"
        let storeName2 = "user_store_2"
        let storeName3 = "user_store_3"

        let store1 = KeyValueEncryptedFileStore.shared(withName: storeName1, forUserAccount: userAccount)
        let store2 = KeyValueEncryptedFileStore.shared(withName: storeName2, forUserAccount: userAccount)
        let store3 = KeyValueEncryptedFileStore.shared(withName: storeName3, forUserAccount: userAccount)

        XCTAssertNotNil(store1)
        XCTAssertNotNil(store2)
        XCTAssertNotNil(store3)

        // Verify stores exist on disk
        let storeDirectories = try? FileManager.default.contentsOfDirectory(atPath: userPath(userAccount))
        XCTAssertEqual(storeDirectories?.count, 3, "Number of directories don't match number of stores created")

        // Verify names
        let storeNames = KeyValueEncryptedFileStore.allNames(forUserAccount: userAccount)
        XCTAssertEqual(storeNames.count, 3)
        XCTAssertTrue(storeNames.contains(storeName1))
        XCTAssertTrue(storeNames.contains(storeName2))
        XCTAssertTrue(storeNames.contains(storeName3))

        KeyValueEncryptedFileStore.removeShared(withName: storeName2, forUserAccount: userAccount)
        XCTAssertEqual(KeyValueEncryptedFileStore.allNames(forUserAccount: userAccount).count, 2)

        KeyValueEncryptedFileStore.removeAll(forUserAccount: userAccount)
        XCTAssertEqual(KeyValueEncryptedFileStore.allNames(forUserAccount: userAccount).count, 0)
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
        let store = createStore(withName: "new_store")
        XCTAssertEqual(store?.storeVersion, 2)
    }

    func testV1StoreVersion() {
        let store = createV1Store(withName: "legacy_store")
        XCTAssertEqual(store?.storeVersion, 1)
    }

    func testStoreWithUnreadableVersion() {
        var store = createStore(withName: "new_store")
        XCTAssertNotNil(store)
        let versionFileURL = store!.directory.appendingPathComponent("version")
        let badVersionData = "bad_version_data".data(using: .utf8)!
        try? badVersionData.write(to: versionFileURL)
        store = createStore(withName: "new_store")
        XCTAssertNil(store)
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
        let store = createStore(withName: storeName)
        XCTAssertEqual(store?.name, storeName, "Store names don't match")
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
        let store = createStore(withName: "test_entries")!
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
        let store = createStore(withName: "test_subscript_save_remove")!
        let key = "key"
        let value = "value"
        store[key] = value
        XCTAssertEqual(value, store[key])
        store[key] = nil
        XCTAssertNil(store[key])
    }

    func testRemoveAll() {
        let entryCount = 20
        let store = createStore(withName: "test_remove_all")!
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
        let store = createStore(withName: "test_all_keys")!
        let entryCount = 12
        var expectedKeys = [String]()
        for i in 0..<entryCount {
            let key = "key\(i)"
            let value = "value\(i)"
            let saveSuccess = store.saveValue(value, forKey: key)
            XCTAssertTrue(saveSuccess)
            expectedKeys.append(key)
        }
        let keys = store.allKeys()
        let sortedKeys = keys?.sorted()
        let sortedExpectedKeys = expectedKeys.sorted()
        XCTAssertEqual(sortedKeys, sortedExpectedKeys)
    }

    func testV1StoreAllKeys() {
        let store = createV1Store(withName: "test_all_keys_v1")!
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
        let store = createStore(withName: "test_overwrite_value")!
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
        let store = createStore(withName: "test_is_empty")!
        XCTAssertTrue(store.isEmpty())
        store.saveValue("value", forKey: "key")
        XCTAssertFalse(store.isEmpty())
    }

    func testStoreEncryption() {
        let store = createStore(withName: "test_store_encryption")!
        let value = "value"
        store.saveValue(value, forKey: "key")

        // Read value directly from file, shouldn't be the same as the unencrypted value
        let files = try? FileManager.default.contentsOfDirectory(atPath: store.directory.path)
        XCTAssertNotNil(files)
        XCTAssertEqual(files?.count, 4, "Unexpected number of files in store")
        let valuePath = (store.directory.path as NSString).appendingPathComponent(files![0])
        let fileData = FileManager.default.contents(atPath: valuePath)
        let valueData = value.data(using: .utf8)
        XCTAssertNotEqual(fileData, valueData)
    }

    func testExistingFile() {
        let fileName = "existing_file"
        try? SFDirectoryManager.ensureDirectoryExists(globalPath())
        let filePath = (globalPath() as NSString).appendingPathComponent(fileName)

        // Create file
        let fileContents = "existing_file_contents"
        try? fileContents.write(toFile: filePath, atomically: false, encoding: .utf8)

        // Shouldn't be able to create store at the same location as the existing file
        let store = createStore(withName: fileName)
        XCTAssertNil(store)
    }

    func testBinaryStorage() {
        let store = createStore(withName: "test_binary_storage")!

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
        return SFDirectoryManager.sharedManager().globalDirectory(ofType: .documentDirectory, components: ["key_value_stores"]) ?? ""
    }

    private func userPath(_ user: UserAccount) -> String {
        return SFDirectoryManager.sharedManager().directory(forUser: user, type: .documentDirectory, components: ["key_value_stores"]) ?? ""
    }

    private func createStore(withName name: String) -> KeyValueEncryptedFileStore? {
        let parentDirectory = globalPath()
        return KeyValueEncryptedFileStore(parentDirectory: parentDirectory, name: name)
    }

    private func createV1Store(withName name: String) -> KeyValueEncryptedFileStore? {
        let store = createStore(withName: name)
        guard let store = store else { return nil }
        let versionFileURL = store.directory.appendingPathComponent("version")
        try? FileManager.default.removeItem(at: versionFileURL)
        return createStore(withName: name)
    }
}
