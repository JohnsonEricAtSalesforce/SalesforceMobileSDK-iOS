# Phase 2 — PR Escalation Summary (for human review)

**Purpose.** Phase 2 of the ObjC→Swift test migration executed the live-org test suites, oracle-compared
against the unmigrated `.dev` clone (`b155f785d`), and drove both schemes green. Along the way it touched or
uncovered a number of **escalation-class** surfaces (per project CLAUDE.md: OAuth/token/credential handling,
account switching, public API, sync engine, localization, build system). This file collects them all in one
place so a human reviewer can sign off before any PR merges. **Nothing here changes the upstream sync marker
(`b5d37d807`).**

Branch: `feature/objc-to-swift-test-migration` (fork). This is NOT a merge to `dev`.

---

## A. Production changes ALREADY MADE in Phase 2 (committed, need PR sign-off)

These were genuine migration regressions vs the oracle, fixed to restore parity. All are behavior-restoring
(bring the Swift port back in line with the shipped ObjC behavior), but they touch escalation surfaces:

| # | Commit | File / surface | Change | Escalation class |
|---|--------|----------------|--------|------------------|
| A1 | `a88baa778` | `SFSDKCollectionSubResponse.objectId` (SDKCore, public) | Restored optionality `String` → `String?` (`dict["id"] as? String`) to match oracle's nullable `NSString*`; also fixed a latent MobileSync `parseIdsFromResponses` empty-id bug + 9 `.objectId?.hasPrefix` test sites | **Public API** (Composite/collection response) |
| A2 | `2df73b842` | `SFRestAPI+QueryBuilder.soqlQuery` (SDKCore, public REST) | `Array(Set(fields))` → order-preserving dedup; fixes non-deterministic SOQL field ordering in generated queries | **Public REST output** |
| A3 | `c20930fe1` | parent-children sync-UP (MobileSync sync engine) | `dict[key] as Any` boxed a Swift Optional into children-lookup SmartSQL (`IN ('Optional(local_…)')` → 0 children); guard-unwrap at both call sites + `unwrapForSql()` | **Sync engine** |
| A4 | `aae35c2d1` | `cleanResyncGhosts` (MobileSync sync engine) | Swift `NSMutableOrderedSet.array` frozen-snapshot captured ghost ids BEFORE `removeObjects(in:)` → deleted non-ghosts; snapshot AFTER removal | **Sync engine** |
| A5 | `181386e4e` | no-type sync-up (MobileSync sync engine) | Empty objectType coerced to `"null"` → `/sobjects/null` → 404, matching oracle (was `/sobjects/` → 405) | **Sync engine** |
| A6 | `c6045477e` | SFSyncOptions fieldlist + 3 reSync targets (MobileSync) | Fieldlist missing-key → `[]` not nil; raw `Optional("…")` in reSync SOQL fixed; `SFSyncTask` `UInt(-1)` trap fix | **Sync engine** |

Notes:
- A1 and A2 change **public API surface / public output** and warrant the closest review (downstream apps).
- A3–A6 are sync-engine correctness fixes; each was validated against the oracle to be behavior-restoring.
- Test-only / test-fidelity fixes (`bee3d8179`, `3177f3980`, `271836232`, `74567e3e7`, isolation hardening
  commits) are NOT escalation and are documented in `.claude/phase2-regression-worklog.md`; listed there for
  completeness, not repeated here.

---

## B. Production regression FOUND but deliberately NOT fixed (needs human decision)

### B1. `currentUserAccount` public setter is gated + persists identity (account switching / public API)
- **Where:** `SFUserAccountManager.swift` — public `currentUserAccount` setter (line ~234) routes to
  `setCurrentUserInternal` → `setCurrentUserInternalFull` (line ~2819).
- **Divergence:** The oracle's `currentUser` is `@synthesize currentUser = _currentUser` with
  `NS_SWIFT_NAME(currentUserAccount)` and only a custom *getter*; setting `currentUserAccount = user` uses the
  **synthesized setter** = bare `_currentUser = user` (no gate, no persistence). The migration's setter
  **rejects** any user not already in `userAccountMap` (logs "Cannot set the currentUser…") and, on success,
  persists `LastUserIdentity` to `NSUserDefaults`.
- **Proof:** Controlled experiment on both clones from a freshly-erased sim: oracle passes the
  `testNotEnabled → testShouldShowBackButton` pair; migration fails. Reverting the test helper to the
  oracle's upsert-less `createUser` makes `testNotEnabled` fail `XCTAssertNotNil` — i.e., the migration
  silently DROPS the set for an unmanaged user.
- **Symptom:** `BiometricAuthenticationManagerTests.testNotEnabled` and
  `NativeLoginManagerTests.testShouldShowBackButton` fail in full-suite ordering (a prior test's `upsert`ed
  account leaks via the disk plist + `LastUserIdentity`, which the getter re-resolves).
- **Blast radius:** LOW in practice — production login flows always `upsert` before setting the current
  user, so the gate never bites internally. It only affects an external consumer that directly assigns
  `manager.currentUserAccount = <unmanaged user>` (a no-op in migration, succeeds in oracle).
- **Why deferred:** CLAUDE.md escalation — "any change to account switching behavior" → STOP and flag. A prod
  change to the account-management setter must be human-reviewed. **Options for the reviewer:** (i) make the
  migration setter accept an unmanaged user like the oracle's synthesized setter (closest to shipped
  behavior); or (ii) keep the gate as an intentional hardening and instead adjust the two tests' teardown to
  clear the disk plist. Recommendation: (i), to preserve byte-faithful public behavior.

### B2. `testAssertionForUnauthenticatedClient` — restore requires a prod assert→NSException change
- **Where:** `SFRestAPI.swift:297` `assert(!request.requiresAuthentication, "Use RestClient sharedInstance
  for authenticated requests")`.
- **Divergence:** Oracle `SFRestAPI.m:295` uses `NSAssert(...)` → a **catchable** `NSInternalInconsistency
  Exception` that the ObjC test `@try/@catch`es. The migration's Swift `assert()` is a non-catchable process
  trap (and is compiled out in release builds). `SFSDKCatchException` (bridge exists) cannot catch it.
- **Status:** Test left **documented-blocked** (unrestored). Restoring it faithfully means converting the
  production guard on the public REST send path to an unconditionally-raised `NSException` — an
  escalation-class REST-behavior change — which is deferred to human review rather than made unreviewed to
  restore one defensive-assert test.
- **Option for reviewer:** if desired, change `SFRestAPI.send(...)` to raise a catchable
  `NSException(.internalInconsistencyException)` (mirrors the OAuth NSAssert→catchable fix already done in
  `SFOAuthCoordinator.swift`, see [[project_oauth_nsassert_fix]]), then restore the test using the existing
  `SFSDKCatchException` bridge. Behavior change: the precondition would then fire in all build configs
  (release included), which is stricter than both the Swift `assert` and ObjC's `NSAssert` under
  `NS_BLOCK_ASSERTIONS`.

---

## C. Escalation-class items carried over from Phase 1 porting (already flagged, listed for the PR)

These were flagged during Phase 1 unit porting and are already recorded in memory; collected here so the PR
reviewer sees the full escalation set in one place. Full detail in the per-unit memory
([[project_sync_job_review]] and unit notes):

- **OAuth / token / credential:**
  - `SFSDKTokenRefreshCoordinator` (NEW, unit 44) — coalesces concurrent per-credential refreshes.
  - `SFOAuthSessionRefresher` **DEPRECATED** (14.0→15.0) with non-deprecated internal seams (unit 44).
  - App Attestation refresh-error classification + NEW public `SFLogoutReason` case
    `SFLogoutReasonAppAttestationFailed` (unit 45) — **additive public API**.
  - Typed `SFOAuthErrorCode` enum (unit 38); iOS RTR feature flag (unit 37).
  - iOS26 login-host classifier `SFSDKAuthErrorManager.errorIsHostConnectionFailure(_:)` (unit 46).
  - Nil-sceneId advanced-auth callback crash fix (unit 43).
  - OAuth NSAssert→catchable + fidelity fixes #1/#2/#3/#5 (see [[project_oauth_nsassert_fix]]).
- **Advanced Auth / login UI / public API:**
  - Advanced Auth made the DEFAULT; `forceAdvancedAuthentication` **DEPRECATED** (14.0→15.0) (unit 39).
  - Invalid login-host recovery + input validation (unit 40).
- **Localization (`Localizable.strings`):** units 40 (`LOGIN_INVALID_HOST`), 39, 59/88/93 (per porting
  notes) — any new user-facing strings must be called out in the PR description.
- **Build system / dependency bump:** SQLCipher 4.16.0→4.17.0 (unit 42, pre-approved but PR-flag);
  pbxproj/xcconfig structural units (#4077 etc.).
- **Swift-API parity shims** (`f1bc8d5ec`): additive `@nonobjc`/typealias shims across 7 libs files to
  restore Clang-importer Swift names — public-API-adjacent, flagged.

---

## D. Confirmed baselines (NOT regressions — no action needed, documented for context)

- `SalesforceRestAPITests.testRedirect` — 401≠200 on BOTH clones (server/test-org behavior).
- `SFSDKAuthUtilTests.testOpenIDToken` — clean-skip; test org's connected app lacks openid scope (no
  id_token). Oracle only "passed" via an ObjC→Swift non-nullable bridging quirk masking a real nil.
- `BriefcaseSyncDownTests` (7) — clean-skip; Briefcase/Priming feature not provisioned in the test org
  (fails identically on the oracle).

---

## Verification state at close

- Full-suite, single-pass `xcodebuild test`, freshly-erased sim AE4C549A (iPhone 17 Pro), serialized schemes:
  - **MobileSync**: `** TEST SUCCEEDED **`, 227 / 0 / 22.
  - **SalesforceSDKCore**: 224 tests; green modulo `testRedirect` baseline + the B1 escalation regression.
- Marker: `b5d37d807` (unchanged).
- Sources of truth: `.claude/phase2-regression-worklog.md` (detail) + `.claude/live-org-skip-ledger.md`
  (ledger, now CLOSED).
