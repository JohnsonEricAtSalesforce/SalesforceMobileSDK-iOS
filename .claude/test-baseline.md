# Test Baseline — Upstream Sync Verification Gate

**Purpose:** Authoritative set of *known, non-regression* test failures. The sync-job
verification gate (see `.claude/upstream-sync-job.md` Step 5) passes only if the failing-test
identifiers after a port are a **subset** of this set. Any failure whose identifier is NOT
listed here is a candidate regression → **GATE FAIL**, diagnose before advancing the marker.

**This is a shrinking ratchet.** Entries may be *removed* when fixed (P1 FTS work) or when CI
gains coverage. Entries may be *added* only by explicit operator decision with recorded rationale
— never silently, to avoid laundering a new regression into "expected."

**Baseline is keyed on identifiers, not counts.** A count-based gate ("≤N failures") is fooled
when composition changes (one new break + one coincidental pass = same count). Match the *set*.

---

## SmartStore

### `assertion-bug` — FTS AlterTests (P1 follow-up: fix assertion logic)

Confirmed empirically 2026-07-05 (SmartStore scheme). 6 test methods; each runs under both FTS4
and FTS5 configs, so ~12 *executions* fail — this reconciles the 2026-05-25 gate report's
"12 expected failures" vs. "6 FTS tests" wording (both correct, counted differently).
Failure signature: `XCTAssertEqual failed … Wrong columns actual: TABLE__…` in `SFSmartStoreAlterTests.swift`.

- `SFSmartStoreAlterTests/testAlterSoupTypeChangeFullTextToJSON1`
- `SFSmartStoreAlterTests/testAlterSoupTypeChangeFullTextToString`
- `SFSmartStoreAlterTests/testAlterSoupTypeChangeJSON1ToFullText`
- `SFSmartStoreAlterTests/testAlterSoupTypeChangeStringToFullText`
- `SFSmartStoreAlterTests/testAlterSoupWithFullTextIndexesFromFts4ToFts5`
- `SFSmartStoreAlterTests/testAlterSoupWithFullTextIndexesToGetIndexesOnCreatedAndLastModified`

### `pre-existing-nonflaky` — 2 failures unmasked by the P0.2b fix (operator-approved 2026-07-14)

When the P0.2b setUp crash was fixed (see below), these two tests — previously hidden behind the
crash — began executing and failing. They are NOT credentials-related and NOT caused by the fix;
the crash was masking them. Added to the baseline by explicit operator decision with rationale:

- `SFMultipleSmartStoresTests/testGetGlobalStoreNames` — asserts exactly 3 global stores
  (`XCTAssertTrue(array.count == 3)`); fails on global-store test-isolation/ordering sensitivity, not
  on the code under test. Candidate for a follow-up test-isolation fix.
- `SFSmartSqlTests/testCleanupRegexpFaster` — a **performance/timing** assertion
  (`newRegexp × 500 < oldRegexp` and `< 25ms`); inherently load-sensitive (violates the project's
  "no timing-based tests" standard). Candidate to rewrite or remove. NOTE: being timing-based it may
  intermittently PASS — a shrinking-ratchet pass (fewer failures than baseline) is still a gate PASS.

### `env-skip` — MobileSync integration (verified in CI only)

Per gate report: `SyncManagerTestCase` `class setUp()` blocks on `synchronousAuthRefresh()`;
the auth run-loop doesn't integrate with xcodebuild locally. Not counted as pass; deferred to CI.
(Lives in MobileSync scheme; listed here as part of the single baseline registry.)

### `env/org-dependent` — SalesforceRestAPITests.testRedirect (operator-approved 2026-07-15)

`SalesforceRestAPITests.testRedirect` creates a Contact, then GETs
`/services/images/photo/{contactId}` expecting HTTP 200 (assumes a redirect to the default profile
image). Against this test org it returns **401 with no redirect at all**. Empirically confirmed via a
temp diagnostic: `finalURL == requestURL`, `Location` header `nil`, status 401 — the redirect handler
is **never exercised**, so the 401 is the org's *direct* response to a photo request for a freshly
created (photo-less) Contact. The production redirect handler (`SFNetwork.willPerformHTTPRedirection`)
is **byte-faithful to the ObjC original** (verified against 58a0af75d~1). NOT a migration regression —
outcome depends on the org's photo-endpoint behavior/data. 61 other SalesforceRestAPITests pass against
the live org. Baselined by operator decision (investigate-deeper concluded env/org-dependent).
Candidate for a CI-org-specific fixture or removal.

### `pre-existing/old-refresh-flow` — SFSDKAuthUtilTests.testOpenIDToken (operator-approved 2026-07-16)

`SFSDKAuthUtilTests.testOpenIDToken` does a live-org refresh and asserts a non-nil OpenID `id_token`
(line 93). It fails intermittently (nil id_token), and the class `setUp` auth-refresh also HANGS
intermittently (`SFSDKTestRequestListener` status stuck `waiting` → 30s `maxWaitTime` timeout; the
refresh callback never fires — NOT a 429/`invalid_grant`, which would fire the failure callback →
`didFail`). **Proven PRE-EXISTING, not a migration regression, via a 3-way oracle comparison (2026-07-16):**
the identical hang reproduces in the **unmigrated ObjC at our merge-base `6ed0ab40`** (`git worktree`, same
creds/org) — the exact pre-migration source our branch was converted from — while the **current-dev**
oracle (which carries upstream's new *token refresh coordinator*, ~155 commits ahead: 997c4e09a / PR #4087
/ 8f597c962 "Improve error handling at token refresh") runs 9/9 green in the same window. So this is an
old-refresh-flow defect upstream already fixed, independent of the ObjC→Swift migration. Likely
refresh-token rotation (first run w/ a fresh token succeeded; later runs hang on the stale-token response).
Baselined by operator decision. Will be superseded when the refresh-coordinator work is pulled in via the
upstream port queue. See memory [[premigration-oracle-clone]] for the merge-base-oracle method.

---

## ✅ RESOLVED 2026-07-14 (tracker finding P0.2b) — SmartStore setUp crash cluster

The 2026-07-05 run showed ~35 setUp crashes in `SFSmartSqlTests.createUserAccount()` and
`SFMultipleSmartStoresTests.setUpSmartStoreUser()` (47 total failures). **Root cause = the
`OAuthCredentials(identifier:clientId:encrypted:)!` convenience-init-returns-nil bug** (class-cluster
design: keychain storage requires the `OAuthKeychainCredentials` subclass; the base convenience init
returns nil by design). The prior fix `f11e4754f` patched `SFSmartStoreTestCase.swift` but MISSED
these two files.

**Fix (2026-07-14):** swapped both sites to the factory
`OAuthCredentials.credentials(identifier:clientId:encrypted:)`. Verified: SmartStore run went
**47 failures / ~35 crashes → 14 failures / 0 crashes**. The 14 = 12 baselined FTS executions + the
2 `pre-existing-nonflaky` failures now listed in the baseline above. **SmartStore gate is now clean**
(subset of baseline). See tracker P0.2b.

---

## ◐ PARTIALLY RESOLVED 2026-07-14 (tracker finding P0.2c) — SalesforceSDKCore credentials crash cluster

The 2026-07-14 SalesforceSDKCore run (during the #4043 gate) surfaced a large crash cluster.
**The credentials portion — same `OAuthCredentials(...)!` root cause as P0.2b — is now FIXED:** all 10
SDKCore test-helper sites swapped to the `.credentials(...)` factory (2026-07-14). The
credentials-driven crashes are gone (`SFUserAccountManagerTests:649`, `SFUserAccountPhotoTests:71`,
`SalesforceRestAPITests:1147`, `BiometricAuthenticationManagerTests:187`, `NativeLoginManagerTests:129`
no longer crash).

**A DISTINCT second cluster remains → see P0.2d below.** SalesforceSDKCore gate stays **provisional**
until P0.2d is resolved. Until then a port is verifiable against SDKCore only by *scoped* evidence:
build ✓ + the tests nearest the change pass + no failure touches the changed code (how #4043 was
accepted).

## ✅ RESOLVED 2026-07-14 (tracker finding P0.2d) — SalesforceSDKCore migration-artifact crashes

All three sub-causes FIXED and verified against the full SalesforceSDKCore suite (2026-07-14,
`test-without-building`, runtime-resolved iPhone sim). Crash types eliminated: **0 auth-assert fires,
0 unimplemented-initializer traps, 0 race-test index-out-of-range** (down from ~11 root-crashing
classes / cascade of ~71). Fixes:
- **A** — removed the dead `path` assert in `SFSDKAuthCommand.requestURL()` (`SFSDKAuthCommand.swift:47`).
  The ObjC original left `path` nil so `NSAssert` was a runtime no-op; `path` is unused in the URL and
  never set by any subclass. `scheme`/`version`/`command` asserts kept (live + populated). Verified:
  all `SFSDKURLHandlerManagerTest`/IDP-command crashes gone.
- **B** — `SFSDKEncryptedURLCache` now overrides URLCache's designated initializers
  (`init(memoryCapacity:diskCapacity:diskPath:)` + the `cacheDirectory:` variant) forwarding to
  `super`, matching the ObjC surface. Also fixed a latent bug: the prior `self.init()` convenience init
  silently dropped the capacity args (zero-capacity cache). The test subclass
  `TestSFSDKEncryptedURLCache` (SFSDKURLCacheTests.swift) also needed the designated init (declaring its
  own init blocks auto-inheritance). Result: `testRestCalls`, `testSettingCacheTypes`, `testNilURL` now
  PASS. **ESCALATION-ADJACENT** (RestAPI encrypted-cache path) — flagged for review in commit/PR.
- **C** — `SFRestAPIDataTaskRaceTests.deliverResponse(at:)` now bounds-guards the pending-protocols
  index (test-only), converting a host-crashing trap into a soft `XCTFail`. No more suite thrashing.

**Residual (NOT P0.2d, NOT baselined):** 4 assertion-level failures remain in the touched classes —
`SFSDKUrlCacheTests.testEncryptedCacheEntry`/`testNullCacheEntry` (URLCache.shared global-state
test-isolation) and the 2 `SFRestAPIDataTaskRaceTests` double-invoke-guard tests. These are clean
assertion failures (not crashes) and belong to the broader P0.2e layer below.

## UNRESOLVED — NOT baselined (tracker finding P0.2e) — SalesforceSDKCore crash-unmasked failure layer

Fixing the P0.2d crashes stopped the xcodebuild host-restart cascade, which **unmasked a pre-existing
layer of 57 failing tests** (same phenomenon as P0.2b: crashes were hiding real failures behind host
restarts). Full-suite run 2026-07-14 after P0.2d fix: **518 passed / 57 failed / 0 crashes-in-P0.2d-scope**.
Distribution: PushNotificationManagerTests ×13, SFSDKEncryptedPushNotificationTests ×12,
SFUserAccountManagerTests ×6, BiometricAuthenticationManagerTests ×6, SFUserAccountManagerPersisterTests
×4, plus 16 across 11 other classes. Includes **2 NEW crashes outside P0.2d scope**: a test-code
force-unwrap `bioAuthManager.readBioAuthPolicy(...)?.optIn!` at `BiometricAuthenticationManagerTests.swift:85`
(nil-unwrap ×2) and an `Index out of range` in `SFUserAccountManagerPersisterTests.testMultipleAccounts`
(accounts array ×2). NOT baselined — needs its own investigation/operator decision (candidates: real
migration regressions vs. test-isolation). SDKCore gate remains **provisional** until P0.2e is triaged.

### P0.2e first-pass triage (2026-07-15) — 6 root-cause clusters

1. **Identity/credentials cluster (~12): SFUserAccountManagerTests (6) + Persister (4) +
   Notifications (2).** ROOT-CAUSED 2026-07-15 — **shared with cluster #5** (single root cause clears
   BOTH, ~20 tests). Signature: `accountIdentity.userId`/`orgId` empty `""`. The `identityUrl` didSet
   parser in `SFOAuthCredentials.swift:76-92` is byte-identical to ObjC (verified); keychain subclass
   doesn't override. Actual break: `UserAccount` keeps `_accountIdentity` in sync with its credentials
   via **KVO** on `userId`/`organizationId` (`SFUserAccount.swift:469-470` addObserver, `observeValue`
   :452-455 updates `_accountIdentity`). In ObjC these were plain `@property` (KVO-compliant). The Swift
   migration declared them `@objc public var userId/organizationId` **without `dynamic`** — Swift KVO
   requires `@objc dynamic`, so willChange/didChange never fire, observers never trigger, and
   `_accountIdentity` stays at its empty init value. **PARTIALLY RESOLVED 2026-07-15** — required TWO
   production fixes (both migration artifacts, both faithful to ObjC): (a) added `dynamic` to `userId`/
   `organizationId` in `SFOAuthCredentials.swift` (KVO needs it); (b) `SFUserAccount.init(credentials:)`
   pre-assigned `_credentials = credentials` BEFORE calling `setCredentialsInternal`, so its
   `credentials !== _credentials` guard was false and the observer was NEVER registered — the ObjC
   original left `_credentials` nil there. Fixed by initializing `_credentials` to a throwaway
   `OAuthCredentials()` placeholder first (distinct identity → guard passes → observer registers). Result:
   Persister 5/5, Notifications pass, UAM 15/16. **ESCALATION-GATED, operator-approved.**
   **Residuals:**
   - `SFUserAccountManagerTests.testMultipleAccounts`: ✅ **RESOLVED 2026-07-15** — was a THIRD
     production migration artifact (distinct from the KVO pair). Root-caused empirically via a temp
     diagnostic that dumped reloaded key strings: after the disk round-trip the stored
     `UserAccountIdentity` had `orgId` populated but **`userId` EMPTY** (`userId=[] orgId=[00D…EA0]`),
     so a freshly-built identity (userId populated) never matched — hence line 234 (lookup by the
     broken stored key) passed while line 250 (fresh key) missed. **Real cause:**
     `OAuthCredentials.init?(coder:)` assigns `self.identityUrl = …` *inside the initializer*, where
     **Swift suppresses `didSet` property observers** — so the `identityUrl` `didSet` that derives
     `userId`/`organizationId` from the URL path never ran on decode. `organizationId` survived only
     because it is *also* decoded directly (`SFOAuthOrganizationId`); `userId` has no direct decode and
     relied entirely on the `didSet`, so it was lost on EVERY load-from-disk (production bug, not just
     this test — breaks user lookup/switching after any app relaunch). The ObjC original had no such
     rule: `initWithCoder` calling `self.identityUrl = …` always invoked the setter, deriving both IDs
     (.m:94, 287-288). **Fix (operator-approved, escalation-gated OAuth code):** extracted the URL-path
     derivation into a private `deriveUserAndOrgId(fromIdentityUrl:)` helper called by BOTH the
     `identityUrl` didSet AND `init?(coder:)` after `super.init()`. Archive format unchanged (userId
     still not encoded, faithful to ObjC). **DISPROVEN earlier hypothesis (kept as a caution):** a
     `UserAccountIdentity` hash/isEqual contract violation — canonicalizing `hash` did NOT fix it and
     was reverted. The set-based key mismatch was a *data* bug (empty userId), not a hashing bug.
     New bug-class swept repo-wide: no other production Swift property assigns an observed
     state-deriving `didSet` property inside its own initializer (only `identityUrl` did).
   - Cluster #5 biometric (7) — see below; test-helper bug, not the KVO fix.
   Also WATCH (→ RESOLVED as task #4, see "Notifications regression" section below):
   `SFUserAccountManagerNotificationsTests` — turned out to be TWO stacked migration defects (unsafe
   `perform()` SIGSEGV + `NS_OPTIONS`→enum), not a test-ordering issue. Fixed & verified 5/5.
2. **EncryptedPushNotification cluster (12): SFSDKEncryptedPushNotificationTests.** ✅ RESOLVED
   2026-07-15 (commit pending). Root cause = TEST-ONLY ObjC→Swift bridging bug, NOT production. Each
   test built `let errorPointer = AutoreleasingUnsafeMutablePointer<NSError?>(&errVar)` then passed
   `errorPointer`. `AutoreleasingUnsafeMutablePointer(&x)` binds `&x` to a *temporary* buffer valid only
   for the initializer call, so the callee's `error?.pointee = ...` writes never flowed back to `errVar`
   — `errVar` stayed nil. Tell: `XCTAssertFalse(result)` never failed (0×), only the error-code
   `XCTAssertEqual` (11×) → production `decryptNotificationContent` was correct all along. Fix: pass
   `&errVar` directly to the `NSErrorPointer` param (matches ObjC original `&noSecretError` and Swift
   bridging), removed the 15 `errorPointer` intermediates. Verified: 15/15 pass, 0 crashes. Production
   `SFSDKPushNotificationDecryption.swift` untouched; production callers were already correct.
3. **PushNotificationManager cluster (13): PushNotificationManagerTests.** REST client never called /
   no registration request made ("REST client should have been called", counts 0 vs 1). Smells like a
   mock/network-setup break or a real registration-path regression. Touches push registration.
4. **User-Agent/Network cluster (~4): SFNetworkTests, SalesforceRestAPITests.** `testRequestUserAgent`
   nil UA header; `testSessionSharing` counts 0 vs 2; `testRedirect` 401 vs 200. Network/session config.
5. **Biometric cluster (6 + 2 crashes): BiometricAuthenticationManagerTests.** ROOT-CAUSED 2026-07-15
   — **SAME root cause as cluster #1** (the missing `dynamic` KVO bug). Chain: test `createUser` builds
   a `UserAccount` then assigns `currentUserAccount = user`; the setter (`setCurrentUserInternalFull`,
   gated identically to the ObjC original at old .m:1702-1716) only accepts a user found via
   `userAccount(for: user.accountIdentity)`. Because `_accountIdentity` is empty (KVO never fired), the
   lookup fails, the setter silently drops the assignment, `_currentUser` stays nil → `testNotEnabled`
   fails at :52 and downstream `.optIn!` force-unwrap crashes at :85. Test is Swift-native (authored
   2023, no ObjC original). **REVISED 2026-07-15:** the cluster #1 fix did NOT clear these — the helper
   `createUser` (unchanged since origin) assigns `currentUserAccount = user` WITHOUT ever registering
   the account (no `identityUrl`, no `upsert`), and it builds no identity URL so accountIdentity is
   empty regardless. The correct/working pattern (now-passing SmartStore `setUpSmartStoreUser`): set
   `credentials.identityUrl` → `upsert(user)` → `setCurrentUserInternal(user)`. This is a **test-helper
   bug** (Swift-native test written in the transitional migration era against a not-yet-gated Swift UAM;
   the ObjC setter always gated on managed-account membership — old .m:1702-1716). FIX: update
   `createUser` to set identityUrl + upsert before setting current. The `.optIn!` force-unwrap hardening
   (:85,:93) was already applied. Still open pending that helper fix.
6. **Singletons (~6): SFOAuthInfoTests, SFPreferencesTests, SFSDKAuthUtilTests, URLRequestRestRequestTests,
   SFUserAccountPhotoTests, SalesforceOAuthUnitTests/testCredentialsCoding** — one-off assertions,
   triage individually.

**Recommended order:** #2 (EncryptedPushNotif — 12, self-contained, not escalation-gated) → #5 (Biometric,
kill the 2 remaining crashes) → #1 (identity/credentials — 12, but ESCALATION-GATED, needs approval) →
#3 → #4 → #6. Cluster #1 requires operator escalation approval before any credentials/OAuth code change.

### Cluster #6 resolution (2026-07-16) — part 1 committed, part 2 via the pre-migration oracle
Part 1 (commit 280f13d39): SFPreferences global-pref, URLRequest doubled-path, SFOAuthInfo IDP casing,
testCoordinator, URLRequestRestRequestTests. Part 2:
- **SalesforceOAuthUnitTests/testCredentialsCoding** — already GREEN (resolved by cluster #1 decode fix
  deae6b04b). Confirmed by run.
- **SFUserAccountPhotoTests.testPhotoWithoutCompletionBlock** — FIXED (test-only). Migration changed the
  assertion from ObjC `XCTAssertNotNil(user.photo)` to `XCTAssertTrue(<ref-equality poll>)`; the `photo`
  getter re-decodes from disk into a new UIImage (byte-faithful to ObjC .m:170-185), so ref-equality never
  converges. Restored ObjC assertion. Both photo tests pass. (Uncommitted at time of writing.)
- **SFSDKAuthUtilTests.testOpenIDToken** + a **setUp auth-refresh HANG** — determined PRE-EXISTING, NOT a
  migration regression, via a 3-way oracle comparison (documented for the ratchet):
    * Current-dev oracle (has upstream's NEW token refresh coordinator, ~155 commits ahead): 9/9 green.
    * **Merge-base `6ed0ab40` UNMIGRATED ObjC** (the exact pre-migration source our branch was converted
      from, via `git worktree`): setUp **HANGS** identically (`'didLoad'`→`'waiting'`, 30s timeout,
      Executed 0 tests). Same failure as our migrated branch.
    * Our migrated Swift branch: setUp hangs identically.
  Since the hang reproduces in the pre-migration ObjC, it is an **old-refresh-flow defect that upstream
  fixed via the token refresh coordinator** (997c4e09a / PR #4087 / 8f597c962 "Improve error handling at
  token refresh"), NOT introduced by the migration. Likely refresh-token rotation: first run w/ a fresh
  token succeeded, subsequent runs hang on the stale-token response (old flow never times out cleanly).
  → **Candidates to baseline** (env/pre-existing, like `testRedirect`) pending operator decision; must NOT
  be laundered as migration-caused. See [[premigration-oracle-clone]] for the merge-base-oracle method.

### Notifications regression (task #4, the cluster #1 "WATCH" items) — RESOLVED 2026-07-16 (escalation-approved)
`SFUserAccountManagerNotificationsTests`: 4/5 tests were failing on our branch, 5/5 pass at merge-base
`6ed0ab40` (offline, ephemeral persister — no env confound). TWO stacked migration defects, the first
masking the second. Both operator-approved (credential-handling code, escalation-gated). Fix in
`SFUserAccountManager.applyCredentials` + `SFUserAccount.AccountDataChange`.
- **Defect 1 — unsafe `perform()` bridging → SIGSEGV (unconditional crash, 4/5 tests).** The migration
  rewrote `[credentials hasPropertyValueChangedForKey:@"..."]` (3×) and `[credentials
  resetCredentialsChangeSet]` as `credentials.perform(NSSelectorFromString(...))?.takeUnretainedValue()
  as? Bool`. `hasPropertyValueChangedForKey:` returns a **primitive `BOOL`**, but `perform` is typed
  `Unmanaged<AnyObject>!` — when the property changed (`YES`/`1`) `.takeUnretainedValue()` dereferences
  address `0x1` → **SIGSEGV with NO crash report** (the tell). Crash is on the FIRST such call
  (`accessToken`) for ANY existing-account update, so which key changed is irrelevant — only
  `testNewUser` survived (it takes the `else`/new-user branch and never enters the block). Proven with a
  diagnostic: direct Swift `hasPropertyValueChangedForKey("accessToken")=true` logs fine, then the very
  next `perform()` line crashes the host. **Fix:** call the direct public Swift methods (byte-faithful to
  ObjC .m:1626-1647). **Repo-wide sweep done:** 6 other `perform(...).takeUnretainedValue()` sites
  (SFLogger, SFSDKAILTNPublisher, TestSetupUtils, SFSDKAuthSession, SFMobileSyncObjectUtils,
  SFApplicationHelper) ALL return objects (NSString/NSData/UIApplication/SFLogging) → safe. The
  BOOL-returning one was the only latent SIGSEGV of this class.
- **Defect 2 — `NS_OPTIONS`→plain-`enum` mis-migration → dropped multi-key notification (testMultipleChanges).**
  Unmasked once defect 1 was fixed. ObjC `SFUserAccountDataChange` is `NS_OPTIONS` (bitmask); the
  migration made it `enum AccountDataChange: UInt`, which represents only ONE case. `applyCredentials`
  OR-combines flags, but `AccountDataChange(rawValue: 26)` (communityId|instanceURL|accessToken) →
  **nil** → `.unknown` → notification suppressed → 10s timeout. Single-key tests passed only because
  their combined value equalled one valid case. **Fix (operator chose the faithful option):** convert
  `AccountDataChange` from `enum` to `OptionSet` (struct, raw `UInt`), mirroring `NS_OPTIONS`;
  `applyCredentials` builds the set via `.insert(...)`; the internal-only `notifyUserDataChange` dropped
  `@objc` (OptionSet isn't ObjC-representable; no ObjC callers; userInfo still carries the raw UInt).
  Public Swift type shape change (enum→OptionSet) — no ObjC/archive/notification-wire change.
- **Verified:** Notifications 5/5 pass (match oracle). Broader slice (UAMTests, PersisterTests,
  UserAccountTests, SalesforceOAuthUnitTests) 31/32; the one failure `SFUserAccountManagerTests.testLogin`
  is a **live-org refresh 20s timeout that reproduces IDENTICALLY at merge-base ObjC** (.m:396) — same
  pre-existing old-refresh-flow class as `testOpenIDToken`, NOT caused by this change. MobileSync (top of
  dep chain) builds clean against the new public type. See [[notifications-change-regression-2026-07-16]].

## (historical) P0.2d root-cause analysis — three independent migration artifacts

Distinct from the (now-fixed) credentials cluster. Root-caused 2026-07-14: **three independent
migration artifacts** where a Swift construct crashes on input the ObjC original tolerated. All are
production-Swift bugs (not test bugs) introduced by the ObjC→Swift migration, provable by: the ObjC
`.m` reference tolerates the same input, and the tests are byte-equivalent to their passing `.m`
originals.

**Sub-cause A — `SFSDKAuthCommand.requestURL()` empty-string asserts (DOMINANT, ~22 crashes).**
`SFSDKAuthCommand.swift:47-50` asserts `scheme`/`path`/`version`/`command` are non-empty. In Swift
these properties default to `""`; `path` is never set by the SP/IDP command subclasses (and `path`
is NOT even used to build the URL — line 52 uses scheme/host/version/command only). ObjC defaulted
them to `nil`, and `[nil sfsdk_isEmptyOrWhitespaceAndNewlines]` returns `NO`, so `NSAssert(NO==false)`
= `NSAssert(true)` PASSED. Swift `"".isEmpty == true` → `assert(false)` → CRASH. The migration
translated `nil`-tolerant ObjC asserts into empty-string-fatal Swift asserts.
- Fix candidate: remove the `path` assert (it is dead — `path` is unused in `requestURL()`), OR relax
  the asserts to match ObjC nil-tolerance. Do NOT "fix" by making tests set a dummy path — that hides
  a real production behavior change (fresh command now crashes where it used to build a URL).
- Tests hit: `SFSDKURLHandlerManagerTest` (×7), `SFSDKIDPLoginRequestCommandTest`,
  `SFSDKAuthRequestCommandTest`, `SFSDKIDPAuthCodeLoginRequestCommandTest`,
  `SFSDKSPLoginResponseCommandTest`, `SalesforceOAuthUnitTests`.

**Sub-cause B — `SFSDKEncryptedURLCache` unimplemented designated initializer (~6 crashes).**
Fatal: "Use of unimplemented initializer 'init(memoryCapacity:diskCapacity:diskPath:)'". The ObjC
class implemented `initWithMemoryCapacity:diskCapacity:directoryURL:` forwarding to `super`; the Swift
migration replaced it with a `cacheDirectory:` convenience init that calls `self.init()` and does NOT
override URLCache's designated initializers. When `URLSession`/`URLCache.shared` instantiates the
cache via the standard `init(memoryCapacity:diskCapacity:diskPath:)`, Swift traps.
- Fix candidate: override the real URLCache designated initializer(s) forwarding to `super`, matching
  the ObjC surface. Production bug (affects any consumer setting an encrypted shared cache).
- Tests hit: `SFSDKUrlCacheTests` (testRestCalls, testSettingCacheTypes, testNilURL).

**Sub-cause C — `SFRestAPIDataTaskRaceTests` index-out-of-range (~4 crashes, likely TEST-only).**
`ContiguousArrayBuffer:692` via `DeferredURLProtocol.pendingProtocols[index]` (line 71). A test-harness
race: `deliverResponse(at:)` indexes the pending-protocols array before the protocol has registered.
This is the ONE sub-cause that looks like a test-infra bug, not a production migration artifact.
- Fix candidate: guard the index / wait for registration in the test harness.

**Deliberately NOT baselined** (would be laundering; A/B are real production regressions that must be
FIXED, not accepted). The cascade inflates the reported set to ~71; the true root-crash set is the
~11 classes above. Full SDKCore gate remains provisional until A + B (production) are fixed; C is
test-only. All three are separate from the credentials fix.

## Provenance

| Field | Value |
|-------|-------|
| Last confirmed | 2026-07-05 (SmartStore scheme, empirical run) |
| Simulator | runtime-resolved iPhone (name-agnostic per P0.1) |
| Run totals | 177 executed / 130 passed / 47 failed / 0 skipped |
| Baseline (assertion-bug) | 6 FTS methods (~12 executions) |
| Quarantined (not baselined) | ~35 setUp-crash cases → P0.2b |
| Not run locally | MobileSync integration (env-skip) |

> Re-confirm this baseline whenever the toolchain (Xcode/simulator/runtime) changes — a device
> first-booted for a fresh run can shift environment-sensitive behavior.
