# Upstream Sync Backlog Ledger

Marker (done floor): bac017113  ·  origin/dev HEAD: bac017113  ·  0 behind (queue DRAINED)  ·  Updated: 2026-07-18 (#4035→0da03630e ported [Cat-F sample/UI, verbatim] — LAST unit; contiguous prefix complete → marker ADVANCED 6ed0ab40→bac017113. Prior: #4047→18d10ada9, #4039→e269a42c9 [pre-map was BACKWARDS — corrected], #4046→0abe5ed79, #4040→ad2f35a05, #4042→b97f7f579, #4041→d0f3596f1, #4044→98d2111f0)

> Pre-mapping pass: 34 upstream commits grouped into 12 first-parent units and classified by net-diff
> file footprint. Grouping uses first-parent history of `origin/dev` (top-level landings), not raw
> `rev-list` — this correctly excludes the master-merge sub-history. See `upstream-sync-job.md` Step 5.
>
> **Escalation review (2026-07-14):** all 5 escalation-sensitive units reviewed against their upstream
> diffs and **operator-APPROVED to port**. Port-readiness verified against the branch:
> `DomainDiscoveryCoordinator` exists (#4046 dep OK); `SFUserAccount.swift` has the identical
> `syncQueue` (#4042 = clean 1:1 wrap); biometric `presentOptInDialog`/`hasBiometricOptedIn` exist but
> `automaticPresentation` is NEW and arrives via #4041's own `.swift` hunks. #4039 approved WITH the
> caveat that it reverses a public-API deprecation — see its detail block; keep the SDK-owner flag.
>
> **Sequencing:** we port in DEPENDENCY order, which is NOT strictly the upstream chronological order —
> see "Migration order vs. original history" at the bottom.

## Migration status
████████████████████  12/12 units done (100%; ported+skipped)   ·   libs/-impacting: 8/8   ·   QUEUE DRAINED

| Status        | Cnt | Units |
|---------------|-----|-------|
| ✅ ported     |  9  | #4043 #4042 #4041 #4044 #4040 #4046 #4039 #4047 #4035 |
| 🔬 analyzed   |  0  | — |
| 🚧 in-progress|  0  | — |
| ⏸ deferred    |  0  | — |
| ⏭ skipped     |  3  | #4038 (buggy method not in migrated Swift surface), master-merge×2 (empty net diff) |
| ⬜ pending    |  0  | — |

## Units
| PR / unit | Members (first-parent range) | Cat | Status | Port commit | Notes |
|-----------|------------------------------|-----|--------|-------------|-------|
| #4042 SFUserAccount thread-safety race | bac017113 (squash) | B | ✅ ported | b97f7f579 | `syncQueue.sync{}` wrap of encode(with:) (+ .m ref synced verbatim); build ✓; testUserAccountEncoding ✓ (runs, not live-gated) |
| #4047 nightly schedules + security | 97ab8b544 (squash) | F | ✅ ported | 18d10ada9 | `.github/workflows/*` (6 files) only — all matched upstream pre-image → applied post-image VERBATIM (== upstream byte-for-byte); weekday nightly schedule + Actions security hardening (script-injection env: vars, least-priv secrets, persist-credentials:false); YAML valid; ⚠ escalation (CI-config + security) — operator-approved verbatim, flag in PR |
| #4046 don't add my domain | c0c3f5a01 (merge, 1 PR-side) | B | ✅ ported | 0abe5ed79 | dropped `loginHost=myDomain` in SFOAuthCoordinator.handleCustomDomainUpdate (+ .m ref verbatim); added `isDiscoveryLogin` guard in SFUserAccountManager.setCurrentUserInternalFull (.m stub, no ref-sync); non-deprecated `isDiscoveryDomain(_:)` overload (no warning); NEW WelcomeDiscoveryLoginHostTests.swift (6 tests, NOT live-gated) + pbxproj (upstream UUIDs, additive); build ✓ (no new warnings), 6/6 ✓; ⚠⚠ escalation (OAuth/login-host + build-system pbxproj) — flag in PR |
| #4044 remove redundant biometric auto-present | 03f1d1863 (merge, 1) | B | ✅ ported | 98d2111f0 | removed viewDidLoad auto-present block from SFLoginViewController.swift (+ .m ref verbatim); build ✓; ⚠ escalation (biometric/login-UI) — flag in PR |
| #4041 biometric opt-in auto-present + lock | d73eb2a0e (merge, 5) | B | ✅ ported | d0f3596f1 | NEW `automaticPresentation` (protocol+Internal default true); auto-present in lock() + retrievedIdentityDataImpl opt-in dialog; 7 new tests + mock conformance; build ✓, 7/7 + RetryPolicy ✓ (testNotEnabled = pre-existing P0.2e ordering artifact, not induced); ⚠ escalation (biometric/lock) — flag in PR |
| #4043 fix trait collection warning | 36f6bf636 (merge, 1) | B | ✅ ported | (pending commit) | non-escalation; registerForTraitChanges in SFSDKUITableViewCell.swift + RootViewController.swift (Cat-A verbatim); build ✓, scoped tests ✓; SDKCore gate provisional per P0.2c |
| MASTER merge (a2d6db8ae) | a2d6db8ae | — | ⏭ skipped | — | "Merging master into dev" — empty net diff (no-op) |
| #4040 hide nav bar on native login | 881c626eb (merge, 2) | B | ✅ ported | ad2f35a05 | one-line `setNavigationBarHidden(true,animated:false)` in `presentLoginViewImpl` native-login branch (+ new test); .m stub not ref-synced; build ✓, NativeLoginManagerTests 6/6 ✓ (new test not live-gated); ⚠ escalation (login-UI) — flag in PR |
| #4039 auth-loading default + deprecate property | d4a9ce0db (merge, 2) | B | ✅ ported | e269a42c9 | ⚠ PUBLIC-API — pre-map was BACKWARDS (see detail): actually a NEW deprecation of `showAuthWindowWhileLoading` (removal 15.0) + default flip NO→YES. Swift: `@available(deprecated)` public computed wrapper over new `internal showAuthWindowWhileLoadingInternal=true`; 2 coord reads use backing (warning-free = Swift equiv of SFSDK_USE_DEPRECATED guards); .m ref-synced verbatim; .h(gutted)/.m(stub) no target. +1 default-flip test. Build ✓ 0 warnings, 23/23 OAuth ✓; SDK-owner flag STAYS raised |
| #4038 fix hardcoded log level | 439d33e90 (merge, 1) | B→skip | ⏭ skipped | ref-sync only | buggy variadic `format:` method NOT in migrated Swift surface — no compiled Swift behavior to fix; SFLogger.m ref synced to upstream. See detail + ⚠ dropped-API flag. |
| MASTER merge (9bf7b52f2 #4037) | 9bf7b52f2 | — | ⏭ skipped | — | "Merge from master" — empty net diff (no-op) |
| #4035 RTR login UI tests + config | d340d5437 (merge, ~7) | F | ✅ ported | 0da03630e | 8 files (7 pre-existing + new RTRLoginTests.swift), all matched upstream pre-image → applied post-image VERBATIM (== upstream byte-for-byte); +230/-41. No pbxproj (AuthFlowTester uses synchronized folder groups; upstream touched none). NO runnable gate: RTR tests are live-org UI tests gated on gitignored `ui_test_config.json` (absent both dirs); AuthFlowTester scheme fails to compile but PRE-EXISTING+unrelated — with #4035 stashed the sample still fails on `RestClient.shared` (RevokeView) + `AuthHelper.registerBlock` (SceneDelegate), files #4035 doesn't touch. Sample app never ported to migrated Swift API → separate migration-parity follow-up |

## Category-B detail

> Confidence key: **[target-confirmed]** = exact Swift file + concept located; **[needs-trace]** =
> Swift target identified but the precise landing point still needs confirmation before porting.

### #4042 — Fix thread-safety race in SFUserAccount encodeWithCoder  [target-confirmed] · ✅ APPROVED
- **Intent:** `encodeWithCoder` read ivars without synchronizing while setters use `dispatch_barrier_async`,
  racing to capture stale/nil values. Upstream wraps the encode in `dispatch_sync(_syncQueue,…)`.
- **Swift mapping (VERIFIED):** `SFUserAccount.swift:304 func encode(with:)` currently reads the six ivars
  UNGUARDED — exact mirror of pre-fix ObjC. The same primitive exists: `syncQueue` (concurrent
  `DispatchQueue`, `.barrier` writes) at line 151. Port = wrap the encode body in `syncQueue.sync { … }`.
  This is a clean 1:1 — same queue, same pattern already used by the property accessors.
- **Files:** `SFUserAccount.m` → `Classes/UserAccount/SFUserAccount.swift:304` (+ update ObjC reference).
- **Escalation:** credential-adjacent serialization — APPROVED (sync fix, no logic/contract change).

### #4046 — don't add my domain  [target-confirmed] · ✅ APPROVED
- **Intent:** don't persist a My Domain into login-host storage — it pollutes the server picker and
  breaks return-to-Discovery on logout. Two guarded edits: (1) drop `setLoginHost:myDomain` in
  `handleCustomDomainUpdateWithLoginHint`; (2) add `isDiscoveryDomain:` guard before persisting
  `credentials.domain` as login host in `setCurrentUserInternal:`.
- **Swift mapping (VERIFIED):** `SFOAuthCoordinator.swift` + `SFUserAccountManager.swift`. The dependency
  `SFDomainDiscoveryCoordinator`/`isDiscoveryDomain:` **exists on branch** as
  `Classes/OAuth/DomainDiscoveryCoordinator.swift` (migrated name, no SF prefix) — no hidden prerequisite.
- **Files:** `SFOAuthCoordinator.m`→`.swift`, `SFUserAccountManager.m`→`.swift` (`setCurrentUserInternal:`);
  **+ `.pbxproj`** (nested Cat-C — only adds a test file ref); + `WelcomeDiscoveryLoginHostTests.swift` (test).
- **⚠ Escalation:** OAuth/login-host behavior — APPROVED.

### #4044 — Remove redundant biometric auto-present from SFLoginViewController  [needs-trace]
- **Intent:** remove a now-redundant biometric auto-present call (paired with #4041's refactor).
- **Swift mapping:** `SFLoginViewController.m` → `SFLoginViewController.swift`. Find + remove the
  auto-present call site.
- **Files:** `SFLoginViewController.m` → `Classes/Login/SFLoginViewController.swift`.
- **Sequencing:** logically follows #4041 — port #4041 first, then this removal.

### #4041 — Add option to automatically present biometric opt-in and lock  [target-confirmed] · ✅ APPROVED
- **Intent:** new option to auto-present biometric opt-in; lock via `handleAppForeground()`; default true.
- **Swift mapping (VERIFIED):** `presentOptInDialog(viewController:)` + `hasBiometricOptedIn()` already
  exist on branch. **`automaticPresentation` does NOT yet exist — it is NEW, introduced by this PR's own
  `.swift` hunks** (`BiometricAuthenticationManager.swift` + `…Internal.swift`). **Apply those `.swift`
  hunks FIRST** (they add the property), THEN translate the `SFUserAccountManager.m` hunk in
  `retrievedIdentityData:` which references it. Order within the unit matters.
- **Files:** 2 prod `.swift` (apply direct, adds `automaticPresentation`) + `SFUserAccountManager.m`→`.swift`
  (`retrievedIdentityData:`) + 2 test `.swift`.
- **⚠ Escalation:** biometric/lock behavior — APPROVED. Port BEFORE #4044 (which removes the now-redundant
  auto-present it supersedes).

### #4043 — Fix trait collection warning  [target-confirmed] · ✅ PORTED
- **Intent:** replace the deprecated `traitCollectionDidChange(_:)` override (iOS 17 deprecation
  warning) with the modern `registerForTraitChanges([UITraitUserInterfaceStyle.self]) { … }` closure
  API, in two independent VCs. Same behavior: re-run the color update when the interface style flips.
- **Swift mapping (VERIFIED):**
  - **Cat-B:** `SFSDKUITableViewCell.swift` (compiled; `.m` de-referenced). Removed the override;
    registered the trait handler in the shared `setupCell()` (called from BOTH `init(style:)` and
    `init(coder:)`) — strictly better than upstream's init-only placement, covers the NIB path too.
    Handler calls `cell.updateLayerColor()`.
  - **Cat-A:** `native/…/RestAPIExplorer/…/RootViewController.swift` — matched upstream pre-image
    exactly; applied upstream's Swift hunk verbatim (byte-identical). Removed override, registered in
    `viewDidLoad`.
- **Files:** `SFSDKUITableViewCell.m`→`Classes/IDP/SFSDKUITableViewCell.swift` (+ ref synced to upstream,
  identical); `RootViewController.swift` (sample app, Cat-A verbatim).
- **Gate:** SalesforceSDKCore. **Build ✓.** Tests: accepted via SCOPED evidence — the IDP command
  tests nearest the changed file (`SFSDKIDPAuthCodeLoginRequestCommandTest`,
  `SFSDKIDPLoginRequestCommandTest`) **passed**; NO failure anywhere touches `SFSDKUITableViewCell`,
  trait changes, or the sample app. A clean full-suite subset check was NOT possible: SalesforceSDKCore
  has a large pre-existing auth-credentials crash cluster (**tracker P0.2c**, root cause = the
  `f11e4754f` `OAuthCredentials(...)!` bug) that is deliberately not baselined. SDKCore gate is
  provisional until P0.2c is fixed; #4043 verified clean against it regardless.
- **Escalation:** none (UI trait-observation refactor, no behavior/contract change).

### #4040 — Hide navigation bar on native login view presentation  [target-confirmed] · ✅ APPROVED
- **Intent:** one line — `setNavigationBarHidden:YES` on the presented native-login nav controller in
  `presentLoginView:`, so custom native-login VCs don't show a stray blue nav bar on re-presentation.
- **Swift mapping:** `SFUserAccountManager.swift`, `presentLoginView(...)`. Self-contained; no new API.
  + `NativeLoginManagerTests.swift` (test, cherry-pickable).
- **Files:** `SFUserAccountManager.m`→`.swift` (`presentLoginView:`) + test `.swift`.
- **⚠ Escalation:** login-UI presentation — APPROVED (single presentation flag, no contract change).

### #4039 — Change default loading behavior + DEPRECATE public property  ⚠ PUBLIC API  [PORTED e269a42c9] · ✅ DONE
- **⚠ PRE-MAPPING WAS BACKWARDS (corrected 2026-07-18 at port time):** the original ledger/analysis
  described this as a deprecation *reversal* (un-deprecate + flip YES→NO + drop guards). The ACTUAL
  upstream commit `d4a9ce0db` does the OPPOSITE — its PR title is "Change default loading and **deprecate**
  property." Verified against the real first-parent diff. Corrected intent below.
- **Actual intent:** (1) flip default `showAuthWindowWhileLoading` **NO→YES** in init
  (`_showAuthWindowWhileLoading = YES`); (2) **ADD** `SFSDK_DEPRECATED(14.0,15.0,…)` to the public property
  in `SFUserAccountManager.h` (newly deprecates it; removal targeted 15.0); (3) **ADD**
  `SFSDK_USE_DEPRECATED_BEGIN/END` guards around the two `showAuthWindowWhileLoading` reads in
  `SFOAuthCoordinator` (didStartProvisionalNavigation / didFinishNavigation).
- **Swift mapping (AS PORTED):** the property + init are Swift-native here (`.h` is gutted — 0 `@property`;
  `SFUserAccountManager.m` is a constants-only stub) so upstream's `.h`/`.m` hunks have NO faithful target.
  - `SFUserAccountManager.swift`: public `showAuthWindowWhileLoading` → `@available(*, deprecated, message:
    "…removed in 15.0…")` computed wrapper over NEW `internal var showAuthWindowWhileLoadingInternal = true`
    (the flipped default). The internal backing is the Swift equivalent of `SFSDK_USE_DEPRECATED_BEGIN/END`:
    in-module reads use it and stay warning-free; external callers of the public property still get warned.
    init sets `showAuthWindowWhileLoadingInternal = true`.
  - `SFOAuthCoordinator.swift`: both load-callback reads switched to the internal backing (warning-free).
  - `SFOAuthCoordinator.m`: ref-synced verbatim (de-referenced/byte-faithful) — applied the two upstream
    `SFSDK_USE_DEPRECATED_BEGIN/END` hunks exactly.
- **Test:** upstream added none; added `test_givenFreshUserAccountManager_…thenDefaultsToTrue` (asserts new
  `true` default + backing round-trip via the internal backing — test itself warning-free).
- **⚠ Escalation — SDK-owner flag STAYS raised:** NEW public-API deprecation (release-notes/deprecation-doc
  item, not silent) + PUBLIC default-behavior flip NO→YES (auth-window timing for all consumers). Ported for
  `origin/dev` parity; NOT cleared for public release without owner sign-off.

### #4038 — Fix hardcoded log level  [TRACED → NO SWIFT TARGET] · ⏭ SKIPPED · ✅ OPERATOR-APPROVED (2026-07-14)
> Disposition + dropped-public-API flag acknowledged by operator 2026-07-14. Unit closed.
- **Intent:** upstream one-liner in the **C-style variadic** `+ log:cls:level:format:, ...` — it
  passed the hardcoded `SFLogLevelDefault` to the backend instead of the caller's `level`. Fix = pass
  `level`. (Net diff: single line in `SFLogger.m:304`.)
- **Trace result (VERIFIED):** the buggy method **does not exist in the compiled Swift surface.**
  - `SFLogger.m`/`SFLogger.h` are **de-referenced** (PBXFileReference only, no "in Sources" entry);
    the compiled logger is `SFLogger.swift`.
  - `SFLogger.swift` has **no variadic `format:` methods at all** — only `message:`-based ones. Swift
    can't express `@objc` C-style variadics, so the entire `…format:, ...` family was dropped in the
    Phase-1 migration (commit 015bc8c56).
  - **No compiled caller needs it:** ObjC callers (`SalesforceRestAPITests.m`,
    `SFSDKSalesforceSDKUpgradeManager.m`, `SFSDKCoreLogger.m`) are de-referenced; compiled
    `SFLoggerTests.swift` exercises only `message:` methods; peer `SFSDKCoreLogger.swift` has its own
    Swift-native `format: String, _ args: CVarArg...` (separate, unaffected).
- **Disposition:** SKIPPED for compiled Swift (no behavior to change). Per Workflow Step 4, the
  de-referenced `SFLogger.m` was overwritten with upstream content at `439d33e90` (now byte-identical)
  so the audit reference stays truthful. No production Swift change ⇒ no build/test gate required.
- **⚠ SEPARATE OWNER FLAG (not #4038):** the migration silently dropped a family of **public** API —
  `SFLogger`'s variadic `format:, ...` convenience methods declared in the public `SFLogger.h`
  (`+log:level:format:`, `+e:/i:/d:/w:/f:/v:/log:format:` and their instance forms). This is a
  public-SDK surface regression introduced by the migration itself, independent of this port. Belongs
  in a migration-parity review / release notes, NOT silently. Does not block advancing past #4038.

### #4043 — Fix trait collection warning  [needs-trace] · ✅ APPROVED (non-escalation)
- (detail above in Units table) `SFSDKUITableViewCell.m` → `SFSDKUITableViewCell.swift` + sample app `.swift`.

## Migration order vs. original history

**Upstream chronological order** (first-parent, oldest→newest):
`#4035 → #4038 → #4039 → #4040 → #4043 → #4041 → #4044 → #4046 → #4047 → #4042`
(the two master-merges interleave but are no-op skips).

**Our porting order** (low-risk / dependency-first). ✅ = done:
1. **Non-escalation B:** ✅ #4038 (skipped), ✅ #4043
2. **Biometric cluster:** ✅ #4041 **then** ✅ #4044
3. **Escalation B:** ✅ #4042, ✅ #4040, ✅ #4046, ✅ #4039 (#4039 last — public-contract change)
4. **F units:** ✅ #4047 (CI, verbatim), ✅ #4035 (sample/UI, verbatim)

**QUEUE DRAINED — all 12 units resolved (9 ported + 3 skipped).** libs/-impacting 8/8. Marker
advanced 6ed0ab40 → bac017113 (origin/dev HEAD); 0 behind. Poller still NOT activated (no cron) —
separate decision.

**Yes — this deliberately re-orders relative to upstream history. Is that safe? Verified yes:**

- The reordering is intentional: risk-ascending (F → simple B → escalation B), not chronological.
- **The one real ordering constraint is preserved:** #4041 **before** #4044 (#4044 removes an
  auto-present that #4041 introduces). Upstream has #4041 before #4044 too — we keep that.
- **No file-level collision from reordering.** The units that share `SFUserAccountManager.swift`
  (#4039 init, #4040 `presentLoginView:`, #4041 `retrievedIdentityData:`, #4046
  `setCurrentUserInternal:`) each touch a **different method** — verified disjoint — so porting them
  in any relative order produces the same final file; no hunk depends on a sibling's edit.
- **`SFOAuthCoordinator.swift` is shared by #4039 and #4046** but again in different regions
  (#4039 = the `showAuthWindowWhileLoading` guard blocks; #4046 = `handleCustomDomainUpdateWithLoginHint`).
  Disjoint — order-independent.

**Why order-independence holds in general here:** we are NOT cherry-picking upstream commits (which
would be order-sensitive to parent state). Each unit is a *semantic re-implementation* against the
current Swift file, so the only thing that matters is the true logical dependency (#4041→#4044), which
we honor. The sync marker stays at the merge-base floor until a contiguous prefix is done; out-of-order
`ported` units live in the ledger frontier exactly as designed.
