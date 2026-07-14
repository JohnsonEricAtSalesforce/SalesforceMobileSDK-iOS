# Upstream Sync Backlog Ledger

Marker (done floor): 6ed0ab40  ·  origin/dev HEAD: bac017113  ·  34 behind (12 logical units)  ·  Updated: 2026-07-14 (pre-mapping pass)

> Pre-mapping pass: 34 upstream commits grouped into 12 first-parent units and classified by net-diff
> file footprint. Category-B units carry intent + candidate Swift target below; deeper Swift-mapping
> confirmation (marked in each detail block) is the remaining per-unit analysis before porting.
> Grouping uses first-parent history of `origin/dev` (top-level landings), not raw `rev-list` — this
> correctly excludes the master-merge sub-history. See `upstream-sync-job.md` Step 5.

## Migration status
░░░░░░░░░░░░░░░░░░░░  0/12 units ported (0%)   ·   libs/-impacting: 0/8

| Status        | Cnt | Units |
|---------------|-----|-------|
| ✅ ported     |  0  | — |
| 🔬 analyzed   |  8  | #4038 #4039 #4040 #4041 #4042 #4043 #4044 #4046 |
| 🚧 in-progress|  0  | — |
| ⏸ deferred    |  0  | — |
| ⏭ skipped     |  2  | master-merge×2 (empty net diff) |
| ⬜ pending    |  2  | #4035 #4047 |

## Units
| PR / unit | Members (first-parent range) | Cat | Status | Port commit | Notes |
|-----------|------------------------------|-----|--------|-------------|-------|
| #4042 SFUserAccount thread-safety race | bac017113 (squash) | B | 🔬 analyzed | — | see detail |
| #4047 nightly schedules + security | 97ab8b544 (squash) | F | ⬜ pending | — | `.github/workflows/*` only — no libs/ impact; cherry-pick candidate |
| #4046 don't add my domain | c0c3f5a01 (merge, 1 PR-side) | B | 🔬 analyzed | — | see detail; ALSO touches `.pbxproj` (Cat-C nested) + 1 test.swift |
| #4044 remove redundant biometric auto-present | 03f1d1863 (merge, 1) | B | 🔬 analyzed | — | see detail |
| #4041 biometric opt-in auto-present + lock | d73eb2a0e (merge, 5) | B | 🔬 analyzed | — | see detail; largest unit (5 commits, incl. 2 prod .swift already) |
| #4043 fix trait collection warning | 36f6bf636 (merge, 1) | B | 🔬 analyzed | — | see detail; + RestAPIExplorer sample .swift |
| MASTER merge (a2d6db8ae) | a2d6db8ae | — | ⏭ skipped | — | "Merging master into dev" — empty net diff (no-op) |
| #4040 hide nav bar on native login | 881c626eb (merge, 2) | B | 🔬 analyzed | — | see detail |
| #4039 auth-loading default + deprecate property | d4a9ce0db (merge, 2) | B | 🔬 analyzed | — | ⚠ PUBLIC API — see detail; ESCALATE |
| #4038 fix hardcoded log level | 439d33e90 (merge, 1) | B | 🔬 analyzed | — | see detail |
| MASTER merge (9bf7b52f2 #4037) | 9bf7b52f2 | — | ⏭ skipped | — | "Merge from master" — empty net diff (no-op) |
| #4035 RTR login UI tests + config | d340d5437 (merge, ~7) | F | ⬜ pending | — | `native/SampleApps/AuthFlowTester/*` + `shared/test/ui_test_config.json.sample` — non-libs; cherry-pick candidate |

## Category-B detail

> Confidence key: **[target-confirmed]** = exact Swift file + concept located; **[needs-trace]** =
> Swift target identified but the precise landing point still needs confirmation before porting.

### #4042 — Fix thread-safety race in SFUserAccount encodeWithCoder  [needs-trace]
- **Intent:** upstream added thread-safety around `encodeWithCoder` in `SFUserAccount.m` to fix a race.
- **Swift mapping:** `SFUserAccount.swift` exists on branch. Confirm whether it retains an
  `encode(with:)`/`NSCoding` path or uses synthesized `Codable`. Race maps to concurrent access of the
  encoded properties → apply idiomatic guard (`OSAllocatedUnfairLock`/actor), NOT literal `@synchronized`.
- **Files:** `SFUserAccount.m` → `Classes/UserAccount/SFUserAccount.swift` (+ update ObjC reference)
- **Open questions:** does the Swift port still implement `NSCoding` for ObjC-compat, or is encoding gone?

### #4046 — don't add my domain  [needs-trace]
- **Intent:** stop appending the my-domain suffix in the OAuth/login-host path.
- **Swift mapping:** touches `SFOAuthCoordinator.m` + `SFUserAccountManager.m`; both have `.swift`
  equivalents (`SFOAuthCoordinator.swift`, `Extensions/UserAccountManager.swift` + `SFUserAccountManager.swift`).
  Locate the my-domain concatenation logic in the Swift OAuth path.
- **Files:** `SFOAuthCoordinator.m`→`.swift`, `SFUserAccountManager.m`→Swift; **+ `.pbxproj`** (nested
  Cat-C — verify no new file ref needed); + `WelcomeDiscoveryLoginHostTests.swift` (test, cherry-pickable).
- **⚠ Escalation:** OAuth/login-host behavior — flag per CLAUDE.md (auth flow change).

### #4044 — Remove redundant biometric auto-present from SFLoginViewController  [needs-trace]
- **Intent:** remove a now-redundant biometric auto-present call (paired with #4041's refactor).
- **Swift mapping:** `SFLoginViewController.m` → `SFLoginViewController.swift`. Find + remove the
  auto-present call site.
- **Files:** `SFLoginViewController.m` → `Classes/Login/SFLoginViewController.swift`.
- **Sequencing:** logically follows #4041 — port #4041 first, then this removal.

### #4041 — Add option to automatically present biometric opt-in and lock  [target-confirmed]
- **Intent:** new option to auto-present biometric opt-in; lock via `handleAppForeground()`; default true.
- **Swift mapping:** 2 production files are ALREADY `.swift` upstream (`BiometricAuthenticationManager.swift`,
  `BiometricAuthenticationManagerInternal.swift`) — those hunks are Cat-A-style (apply directly). Only
  `SFUserAccountManager.m` is the Cat-B part → map to `UserAccountManager.swift`/`SFUserAccountManager.swift`.
  Tests (`BiometricAuthenticationManagerTests.swift`, `URLSessionTask+RetryPolicyTests.swift`) cherry-pickable.
- **Files:** 2 prod `.swift` (direct) + `SFUserAccountManager.m`→Swift (translate) + 2 test `.swift`.
- **⚠ Escalation:** biometric/lock behavior — flag per CLAUDE.md.

### #4043 — Fix trait collection warning  [needs-trace]
- **Intent:** silence a UIKit trait-collection API warning.
- **Swift mapping:** `SFSDKUITableViewCell.m` → `SFSDKUITableViewCell.swift`. + a RestAPIExplorer
  sample `.swift` (RootViewController) — cherry-pickable.
- **Files:** `SFSDKUITableViewCell.m` → `Classes/IDP/SFSDKUITableViewCell.swift`; sample app `.swift`.

### #4040 — Hide navigation bar on native login view presentation  [needs-trace]
- **Intent:** hide the nav bar when presenting native login.
- **Swift mapping:** `SFUserAccountManager.m` → `UserAccountManager.swift`/`SFUserAccountManager.swift`.
  Locate native-login presentation path. + `NativeLoginManagerTests.swift` (test, cherry-pickable).
- **Files:** `SFUserAccountManager.m`→Swift + test `.swift`.
- **⚠ Escalation:** login UI presentation — flag per CLAUDE.md.

### #4039 — Change default loading behavior and deprecate property  ⚠ PUBLIC API — ESCALATE  [target-confirmed]
- **Intent:** change default auth-window-while-loading behavior; **un-deprecate** the public property
  `showAuthWindowWhileLoading` (removes the `SFSDK_DEPRECATED(14.0,15.0,...)` annotation in the `.h`).
- **Swift mapping:** `SFOAuthCoordinator.m` + `SFUserAccountManager.{h,m}` → Swift. The `.h` change is a
  **public-API surface change** — the Swift port must express the same public property WITHOUT the
  deprecation, and the ObjC header reference must be updated to match. Coordinate with the deprecation
  policy (this REVERSES a prior deprecation).
- **Files:** `SFOAuthCoordinator.m`→`.swift`, `SFUserAccountManager.h`+`.m`→Swift (+ ObjC ref update).
- **⚠ Escalation (mandatory human review):** public-API signature + reversal of a deprecation.

### #4038 — Fix hardcoded log level  [needs-trace]
- **Intent:** replace a hardcoded log level in `SFLogger.m` with the configured level.
- **Swift mapping:** `SFLogger.m` → `Classes/Logger/SFLogger.swift` (also `SFDefaultLogger.swift`
  present). Find the hardcoded level and route through configured level.
- **Files:** `SFLogger.m` → `SalesforceSDKCommon/Classes/Logger/SFLogger.swift`.

## Recommended porting order (low-risk first)
1. **F units (cherry-pick, build-verify):** #4047, #4035 — no libs/ impact.
2. **Confirmed-scope B, no escalation:** #4038, #4043.
3. **Biometric cluster (port #4041 then #4044):** related; sequence matters.
4. **Escalation-gated B (need human sign-off):** #4039 (public API), #4046 (auth/my-domain),
   #4040 (login UI), #4042 (thread-safety), #4041 (biometric).
