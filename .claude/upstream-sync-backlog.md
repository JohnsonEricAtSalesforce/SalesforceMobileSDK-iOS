# Upstream Sync Backlog Ledger

Marker (done floor): 6ed0ab40  ·  origin/dev HEAD: bac017113  ·  34 behind (12 logical units)  ·  Updated: 2026-07-18 (#4042 ported → b97f7f579; marker held at 6ed0ab40 — #4035 below it still pending)

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
████████░░░░░░░░░░░░  5/12 units done (42%; ported+skipped)   ·   libs/-impacting: 3/8

| Status        | Cnt | Units |
|---------------|-----|-------|
| ✅ ported     |  2  | #4043 #4042 |
| 🔬 analyzed   |  5  | #4039 #4040 #4041 #4044 #4046 |
| 🚧 in-progress|  0  | — |
| ⏸ deferred    |  0  | — |
| ⏭ skipped     |  3  | #4038 (buggy method not in migrated Swift surface), master-merge×2 (empty net diff) |
| ⬜ pending    |  2  | #4035 #4047 |

## Units
| PR / unit | Members (first-parent range) | Cat | Status | Port commit | Notes |
|-----------|------------------------------|-----|--------|-------------|-------|
| #4042 SFUserAccount thread-safety race | bac017113 (squash) | B | ✅ ported | b97f7f579 | `syncQueue.sync{}` wrap of encode(with:) (+ .m ref synced verbatim); build ✓; testUserAccountEncoding ✓ (runs, not live-gated) |
| #4047 nightly schedules + security | 97ab8b544 (squash) | F | ⬜ pending | — | `.github/workflows/*` only — no libs/ impact; cherry-pick candidate |
| #4046 don't add my domain | c0c3f5a01 (merge, 1 PR-side) | B | 🔬 analyzed · ✅ approved | — | dep `DomainDiscoveryCoordinator` confirmed; + `.pbxproj` (Cat-C nested) + 1 test.swift |
| #4044 remove redundant biometric auto-present | 03f1d1863 (merge, 1) | B | 🔬 analyzed · ✅ approved | — | pairs with #4041 — port AFTER it |
| #4041 biometric opt-in auto-present + lock | d73eb2a0e (merge, 5) | B | 🔬 analyzed · ✅ approved | — | adds NEW `automaticPresentation` via its `.swift` hunks; apply those first |
| #4043 fix trait collection warning | 36f6bf636 (merge, 1) | B | ✅ ported | (pending commit) | non-escalation; registerForTraitChanges in SFSDKUITableViewCell.swift + RootViewController.swift (Cat-A verbatim); build ✓, scoped tests ✓; SDKCore gate provisional per P0.2c |
| MASTER merge (a2d6db8ae) | a2d6db8ae | — | ⏭ skipped | — | "Merging master into dev" — empty net diff (no-op) |
| #4040 hide nav bar on native login | 881c626eb (merge, 2) | B | 🔬 analyzed · ✅ approved | — | self-contained one-line UI flag |
| #4039 auth-loading default + deprecate property | d4a9ce0db (merge, 2) | B | 🔬 analyzed · ✅ approved ⚠ | — | ⚠ PUBLIC-API deprecation REVERSAL — approved; keep SDK-owner flag; see detail |
| #4038 fix hardcoded log level | 439d33e90 (merge, 1) | B→skip | ⏭ skipped | ref-sync only | buggy variadic `format:` method NOT in migrated Swift surface — no compiled Swift behavior to fix; SFLogger.m ref synced to upstream. See detail + ⚠ dropped-API flag. |
| MASTER merge (9bf7b52f2 #4037) | 9bf7b52f2 | — | ⏭ skipped | — | "Merge from master" — empty net diff (no-op) |
| #4035 RTR login UI tests + config | d340d5437 (merge, ~7) | F | ⬜ pending | — | `native/SampleApps/AuthFlowTester/*` + `shared/test/ui_test_config.json.sample`; #4035 also needs `ui_test_config.json` to gate |

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

### #4039 — Change default loading behavior + REVERSE public-API deprecation  ⚠ PUBLIC API  [target-confirmed] · ✅ APPROVED (with caveat)
- **Intent:** (1) flip default `showAuthWindowWhileLoading` YES→NO in init; (2) **remove** the
  `SFSDK_DEPRECATED(14.0,15.0,…)` annotation from the public `.h` (un-deprecates a property that was on
  the 15.0 removal path); (3) drop the `SFSDK_USE_DEPRECATED_BEGIN/END` guards in `SFOAuthCoordinator`.
- **Swift mapping:** `SFOAuthCoordinator.swift` + `SFUserAccountManager.swift`; the public property must
  be expressed WITHOUT the deprecation attribute and the default flipped; ObjC header reference updated.
- **Files:** `SFOAuthCoordinator.m`→`.swift`, `SFUserAccountManager.h`+`.m`→`.swift` (+ ObjC ref update).
- **⚠ Escalation — APPROVED WITH CAVEAT:** operator approved porting this to keep parity with `origin/dev`.
  BUT it reverses a shipped public-API deprecation and flips a default behavior. **Keep the SDK-owner flag
  raised** — this is a public-contract change that belongs in release notes / PR description, not a silent
  port. Do not treat "approved to port" as "cleared for public release without owner sign-off."

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

**Our proposed porting order** (low-risk / dependency-first):
1. **F units:** #4047, #4035 (no libs/ impact; #4035 waits on `ui_test_config.json`)
2. **Non-escalation B:** #4038, #4043
3. **Biometric cluster:** #4041 **then** #4044
4. **Escalation B:** #4042, #4040, #4046, #4039 (#4039 last — public-contract change)

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
