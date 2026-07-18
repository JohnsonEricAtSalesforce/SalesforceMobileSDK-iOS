# Live-Org Skip Ledger — tests that DO NOT actually run locally (2026-07-17)

**Purpose (Task 11, item 3):** an explicit, honest list of test classes/methods that compile and are counted
as "present" but **do not execute** in the local/CI simulator run, so their green status is a SKIP, not a
PASS. This exists so future port work (and the upstream-sync gate) never mistakes "skipped" for "verified."

## Why these skip
All live-org tests authenticate against a real Salesforce org in `class func setUp()` via
`TestSetupUtils.synchronousAuthRefresh()`. The pre-token-refresh-coordinator OAuth refresh flow **hangs** in
the sim test host even with a curl-verified-valid token (see memory [[live-auth-abort-harden-2026-07-17]] /
tracker P0.2h). The hardening fix records `TestSetupUtils.authRefreshDidSucceed` instead of asserting, and
each live class does `try XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed, ...)` in `setUpWithError` — so
these classes **cleanly SKIP** instead of aborting the run. They will execute only once the upstream token
refresh coordinator port lands (unblocking live auth). The merge-base oracle ALSO hangs live auth, so these
are "compare-when-live" on both sides.

## Live-org SKIP-gated classes

### SalesforceSDKCore (gate: `XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed)` in each class)
- `RestClientPublisherTests`
- `RestClientTest`
- `SFSDKAuthUtilTests`
- `SalesforceRestAPITests`  ← includes the 45 restored dropped methods (2026-07-17) + `testAssertionForUnauthenticatedClient` (see below)

### MobileSync (gate: `XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed)` in `SyncManagerTestCase.setUpWithError`, inherited by all subclasses)
- `SyncManagerTests`  ← includes the 3 restored dropped methods (2026-07-17)
- `SyncUpTargetTests`  ← includes the 2 restored dropped methods (2026-07-17)
- `SFSDKSyncsConfigTests`
- `SFLayoutSyncManagerTests`
- `BriefcaseSyncDownTests`
- `SFMetadataSyncManagerTests`
- `ParentChildrenSyncTests`

## Restored-but-not-running (recovered on paper, 2026-07-17)
The 51 dropped live-org methods restored under Task 9 all land in the classes above and therefore **SKIP**
until live auth works. Their oracle-comparison (Task 10) is deferred to when live auth is available; the
oracle hangs the same flow, so neither side runs them today. They are restored so the coverage EXISTS in
source and will execute the moment the coordinator port unblocks auth — closing the "hidden failure" gap the
operator flagged (a future REST/sync port can no longer pass green against absent tests).

## Documented-blocked (cannot run even with live auth, without new infra)
- `SalesforceRestAPITests.testAssertionForUnauthenticatedClient` — asserts an ObjC `NSException` is raised
  when the unauthenticated global `RestClient` makes an authenticated request. Swift can't catch ObjC
  `NSException` natively and this repo has no exception-catching bridge. The orphaned (non-compiled) `.m`
  claims to "preserve" it, but that file has no build-phase Sources entry. Restoring requires an ObjC
  exception-catcher test utility (future work). Left intentionally unrestored.

## How to retire entries here
When the token-refresh-coordinator upstream port lands and live auth succeeds in-sim, re-run each class
WITHOUT the skip and reconcile against the oracle per Task 10; move passing classes off this ledger. Until
then, any gate that reports these as "passing" must annotate them as SKIPPED.
