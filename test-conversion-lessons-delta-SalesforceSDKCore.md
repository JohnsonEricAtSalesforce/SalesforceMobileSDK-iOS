# Test Conversion Lessons Delta - SalesforceSDKCore

## Batch 12

### Files Converted
1. `SFSDKAsyncProcessListener.m/.h` -> `SFSDKAsyncProcessListener.swift` (same dir: `Classes/Test/`)
2. `SFSDKTestCredentialsData.m/.h` -> `SFSDKTestCredentialsData.swift` (same dir: `Classes/Test/`)
3. `SFSDKTestRequestListener.m/.h` -> `SFSDKTestRequestListener.swift` (same dir: `Classes/Test/`)
4. `TestSetupUtils.m/.h` -> `TestSetupUtils.swift` (same dir: `Classes/Test/`)
5. `AppDelegate.m/.h` -> `AppDelegate.swift` (TestApp dir)

### Key Patterns Discovered
- `SFOAuthCoordinatorDelegate` protocol has 4 required methods: `didBeginAuthenticationWith(WKWebView)`, `didBeginAuthenticationWith(ASWebAuthenticationSession)`, `oauthCoordinatorDidBeginNativeAuthentication`, `oauthCoordinatorDidCancelBrowserAuthentication`
- `IdentityCoordinatorDelegate` uses Swift name `IdentityCoordinator` (not `SFIdentityCoordinator`) with methods: `identityCoordinatorRetrievedData(_:)` and `identityCoordinator(_:didFailWith:)`
- `SFSDKCoreLogger.d(cls, message:)` is the static method pattern (not format strings)
- `UserAccountManager.shared` (not `.sharedInstance`)
- `UserAccountManager.oauthClientID` (not `oauthClientId`)
- `UserAccountManager.oauthCompletionURL` (not `oauthCompletionUrl`)
- `OAuthCredentials.domain` is `private(set)` but accessible within module
- `OAuthCredentials` init: `OAuthCredentials(identifier:clientId:encrypted:)`
- Notification keys: `UserAccountManager.userInfoAccountKey` and `UserAccountManager.userInfoAuthenticationTypeKey`
- `UserAccountManager.shared.refresh(credentials:_:)` returns `Result<(UserAccount, AuthInfo), UserAccountManagerError>`
- `SFJsonUtils.object(from: Data?)` and `SFJsonUtils.object(from: String?)`
- `BootConfig` is the Swift name for `SFSDKAppConfig`
- `SalesforceManager.shared` and `SalesforceManager.initializeSDK()` (not `SalesforceSDKManager`)
- `@main` attribute replaces `main.m` for TestApp AppDelegate
- `uniqueUserAccountIdentifier:` was ObjC-only internal method; use `UUID().uuidString` in Swift

## Batch 13

### Files Converted
1. `main.m` -> replaced by `@main` attribute on `AppDelegate.swift` (no separate file needed)
2. `ViewController.m/.h` -> `ViewController.swift` (TestApp dir)
3. `SalesforceOAuthUnitTestsCoordinatorDelegate.m/.h` -> `SalesforceOAuthUnitTestsCoordinatorDelegate.swift` (tests dir)
4. `SFOAuthTestFlowCoordinatorDelegate.m/.h` -> `SFOAuthTestFlowCoordinatorDelegate.swift` (tests dir)
5. `SFCryptoStreamTestUtils.m/.h` -> `SFCryptoStreamTestUtils.swift` (tests dir)

### Key Patterns Discovered
- `SFOAuthCoordinatorDelegate` optional methods use the `@objc optional` pattern - conforming classes only implement them if needed
- `NSException.raise()` pattern preserved for test flow delegates that need to throw ObjC exceptions
- CommonCrypto functions (`CCCryptorReset`, `CCCryptorUpdate`, `CCCryptorFinal`, `CCCryptorGetOutputLength`) work with Data's `withUnsafeBytes`/`withUnsafeMutableBytes`
- `SecRandomCopyBytes` works with `Data.withUnsafeMutableBytes`
- Test flow delegates that use `SFLogger.log(class:level:format:)` map to `SFSDKCoreLogger.d(class, message:)` in Swift
- `XCTestCase` subclasses implementing `SFOAuthCoordinatorDelegate` must also be `NSObject`-based (XCTestCase already is)

## Batch 14

### Files Converted
1. `SFSDKLogoutBlocker.m/.h` -> `SFSDKLogoutBlocker.swift` (119 lines) - Test helper, swizzles logout methods
2. `SFSDKPushNotificationDataProvider.m/.h` -> `SFSDKPushNotificationDataProvider.swift` (115 lines) - Test helper, builds encrypted push notification payloads
3. `SFTestSDKManagerFlow.m/.h` -> `SFTestSDKManagerFlow.swift` (58 lines) - Test helper implementing SalesforceSDKManagerFlow
4. `SFUserAccountPersisterEphemeral.m/.h` -> `SFUserAccountPersisterEphemeral.swift` (50 lines) - In-memory persister conforming to UserAccountPersister
5. `NSString+SFAdditionsTests.m` -> `NSString+SFAdditionsTests.swift` (83 lines) - Tests for entityId18, isEqualToEntityId, unescapeXMLCharacter

### Key API Patterns
- `SalesforceSDKManagerFlow` protocol dropped `handleUserWillSwitch`/`handleUserDidSwitch` in Swift (replaced by notifications)
- `UserAccountPersister` protocol uses `saveAccount(for:)`, `fetchAllAccounts()`, `deleteAccount(for:)` - all throwing
- `EncryptionKey` (was `SFEncryptionKey`) - `init(data:initializationVector:)`, `.key` is `Data?`, `.initializationVector` is `Data`
- `CryptoUtils` (was `SFSDKCryptoUtils`) - `randomByteData(withLength:)`, `aes128EncryptData(_:withKey:iv:)`, `getRSAPublicKeyRef(withName:keyLength:)`, `createRSAKeyPair(withName:keyLength:accessibleAttribute:)`, `encryptData(_:key:algorithm:error:)`
- `PushNotificationManagerConstants.kPNEncryptionKeyName` / `.kPNEncryptionKeyLength` for push notification encryption constants
- NSString extensions: `(str as NSString).sfsdk_entityId18`, `(str as NSString).sfsdk_isEqualToEntityId(_:)`, `NSString.sfsdk_unescapeXMLCharacter(_:)`

## Batch 15

### Files Converted
1. `SalesforceRestAPITests.m` (3211 lines ObjC) -> `SalesforceRestAPITests.swift` (1426 lines) - LARGEST file, comprehensive REST API integration tests

### Key API Patterns
- `RestClient` (was `SFRestAPI`) - `RestClient.shared`, `RestClient.sharedGlobal`, `RestClient.sharedInstance(with:)`
- `RestClient.shared.send(_:failureBlock:successBlock:)` - block-based API
- `RestClient.shared.send(_:requestDelegate:)` - delegate-based API
- API version: pass `nil` for default (no `kSFRestDefaultAPIVersion` in Swift)
- `RestClient.shared.requestForCreate(withObjectType:fields:apiVersion:)`
- `RestClient.shared.requestForUpdate(withObjectType:objectId:fields:apiVersion:)`
- `RestClient.shared.requestForUpdate(withObjectType:objectId:fields:ifUnmodifiedSinceDate:apiVersion:)`
- `RestClient.shared.requestForUpsert(withObjectType:externalIdField:externalId:fields:apiVersion:)`
- `RestClient.shared.requestForDelete(withObjectType:objectId:apiVersion:)`
- `RestClient.shared.requestForRetrieve(withObjectType:objectId:fieldList:apiVersion:)`
- `RestClient.shared.requestForQuery(_:apiVersion:)` / `requestForQuery(_:apiVersion:batchSize:)`
- `RestClient.shared.requestForQueryAll(_:apiVersion:)`
- `RestClient.shared.requestForSearch(_:apiVersion:)`
- `RestClient.shared.batchRequest(_:haltOnError:apiVersion:)`
- `RestClient.shared.compositeRequest(_:refIds:allOrNone:apiVersion:)`
- `RestClient.shared.requestForSObjectTree(_:objectTrees:apiVersion:)`
- `RestClient.shared.requestForCollectionCreate(_:records:apiVersion:)`
- `RestClient.shared.requestForCollectionRetrieve(_:objectIds:fieldList:apiVersion:)`
- `RestClient.shared.requestForCollectionUpdate(_:records:apiVersion:)`
- `RestClient.shared.requestForCollectionUpsert(_:objectType:externalIdField:records:apiVersion:)`
- `RestClient.shared.requestForCollectionDelete(_:objectIds:apiVersion:)`
- `BatchRequestBuilder` / `CompositeRequestBuilder` / `BatchRequest` / `CompositeRequest`
- `BatchResponse` / `CompositeResponse` / `CompositeSubResponse`
- `CollectionResponse` / `PrimingRecordsResponse`
- `SObjectTree(objectType:objectTypePlural:referenceId:fields:childrenTrees:)`
- `FetchNotificationsRequestBuilder` / `UpdateNotificationsRequestBuilder`
- `RestClient.removeSharedInstance(with:)`, `RestClient.userAgentString()`, `RestClient.userAgentString(_:)`
- `RestClient.soqlQuery(withFields:sObject:whereClause:limit:)` / `soslSearch(withSearchTerm:objectScope:)`
- `RestRequest(method:baseURL:path:queryParams:)` / `RestRequest(method:path:queryParams:)`
- `RestRequest.customUrlRequest(withMethod:baseURL:path:queryParams:)`
- `RestRequest.customEndPointRequest(withMethod:endPoint:path:queryParams:)`
- `RestRequest.restUrl(forBaseUrl:serviceHostType:credentials:)`
- `Notification.Name.UserAccountManagerDidRefreshToken` (was `kSFNotificationUserDidRefreshToken`)
- `kSFOAuthErrorDomain`, `kSFOAuthErrorInvalidGrant` still available as global constants
- `UserAccountManager.shared.upsert(_:)` (throwing) - replaces `saveAccountForUser:error:`
- `UserAccountManager.shared.delete(_:)` (throwing) - replaces `deleteAccountForUser:error:`
- `RestRequestDelegate` protocol: `request(_:didSucceed:rawResponse:)`, `request(_:didFail:rawResponse:error:)`

## Batch 16

### Files Converted
1. `SalesforceSDKManagerTests.m` (1123 lines ObjC) -> `SalesforceSDKManagerTests.swift` (585 lines) - SDK Manager tests
2. `NSURL+SFStringUtilsTests.m` -> `NSURL+SFStringUtilsTests.swift` (74 lines) - URL redaction tests

### Key API Patterns
- `SalesforceManager.shared` (was `[SalesforceSDKManager sharedManager]`)
- `SalesforceManager.ailtnAppName` (class property)
- `SalesforceManager.appName` (class property)
- `SalesforceManager.shared.appConfig` is optional `BootConfig?`
- `SalesforceManager.shared.useSnapshotView`, `.snapshotViewControllerCreationAction`, `.snapshotPresentationAction`, `.snapshotDismissalAction`
- `SalesforceManager.shared.useWebServerAuthentication`, `.useHybridAuthentication`
- `SalesforceManager.shared.brandLoginPath`
- `SalesforceManager.shared.appDisplayName`
- `SalesforceManager.shared.sdkManagerFlow` (weak property)
- `SalesforceManager.shared.appConfigRuntimeSelectorBlock`
- `SalesforceManager.shared.appConfig(forLoginHost:callback:)` (was `appConfigForLoginHost:callback:`)
- `SalesforceManager.shared.getDevActions(_:)` returns `[SFSDKDevAction]`
- `SalesforceManager.shared.getDevSupportInfos()` returns `[String]`
- `SalesforceManager.shared.userAgentString(_:)` (instance method)
- `UserAccountManager.shared.oauthClientID` (capital I and D)
- `UserAccountManager.shared.switch(to:)` (was `switchToUser:`)
- `SFOAuthCoordinator.authInfo?.authType` enum: `.webServer`, `.userAgent`
- `URL.sfsdk_redactedAbsoluteString(_:)` takes `[String]` (not nil-able - pass empty array)
- `kSFRedactedQuerystringValue` = `"[redacted]"`
- `kSFDefaultNativeLoginViewControllerKey` (internal constant)
