# Phase 1: Orchestrator and Classification Metrics - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 01-orchestrator-and-classification-metrics
**Areas discussed:** Merge strategy, Auth approach, Test coverage, Metric naming

---

## Merge Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Cherry-pick relevant commits | Pick only orchestrator/classification commits, skip version bumps | |
| Merge the whole branch | git merge, brings everything, may need conflict resolution | |
| Extract the diff as patches | Take cumulative diff, apply manually, most control | Yes |

**User's choice:** Extract the diff as patches
**Notes:** None

### Follow-up: Changelog entries

| Option | Description | Selected |
|--------|-------------|----------|
| Skip changelog entries | Write fresh at release time | Yes |
| Carry them across | Include feature branch entries with adjusted versions | |

**User's choice:** Skip changelog entries -- write fresh at release time

---

## Auth Approach

| Option | Description | Selected |
|--------|-------------|----------|
| SSL client certs (keep as-is) | Standard PE approach, no secrets to manage | Yes |
| RBAC token instead | Bearer token as Puppet parameter | |
| Support both, user chooses | Add auth_method parameter | |

**User's choice:** SSL client certs for now, should only run on the PE server. May need to change in future.
**Notes:** Deferred RBAC token support as a future consideration

### Follow-up: SSL cert path configuration

| Option | Description | Selected |
|--------|-------------|----------|
| Env overrides are sufficient | SSL_CERT_FILE / SSL_KEY_FILE / SSL_CA_FILE env vars | Yes |
| Add Puppet parameters too | Expose as class parameters alongside env overrides | |

**User's choice:** Env overrides are sufficient

---

## Test Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Manifest tests only (keep as-is) | Existing rspec-puppet tests verify params and compilation | |
| Add Ruby unit tests too | Extract collectors, add specs for all scenarios | Yes (initial) |
| Add Ruby tests for error paths only | Middle ground, error/retry specs only | |

**User's choice:** Initially selected "Add Ruby unit tests too", then revised: defer Ruby unit tests until codebase stabilises. Keep manifest tests only for this phase.
**Notes:** "I'm thinking we might push the test work to a later phase, given the amount of rework we have to do. Save the tests until it's a stable codebase, save rework."

### Follow-up: Test design approach (deferred)

| Option | Description | Selected |
|--------|-------------|----------|
| Extract and test generated script | Render EPP, write to temp, test Ruby class | |
| Refactor into separate Ruby lib | Move logic out of EPP into lib/ | |
| You decide | Claude picks | Yes |

**User's choice:** You decide (deferred to when tests are actually written)

---

## Metric Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Names look good as-is | Ship existing puppet_orchestrator_* and puppet_node_group_* names | Yes |
| Review and adjust some | Look at specific names/labels before committing | |
| Add a common prefix | puppet_pdc_orchestrator_* namespace | |

**User's choice:** Names look good as-is

### Follow-up: Label cardinality

| Option | Description | Selected |
|--------|-------------|----------|
| Ship as-is | 50-job default keeps cardinality bounded | Yes |
| Drop job_id labels | Aggregate by task_name/state only | |
| Add a cardinality warning | Log warning when job count exceeds threshold | |

**User's choice:** Ship as-is

---

## Claude's Discretion

- Test design approach when Ruby unit tests are eventually written
- Conflict resolution details during patch application
- Minor code cleanup to align conventions

## Deferred Ideas

- RBAC token authentication -- future consideration for non-PE-server nodes
- Ruby unit tests for collection logic -- deferred until codebase stabilises
- Cardinality warnings for high job counts -- not needed at v1 limits
