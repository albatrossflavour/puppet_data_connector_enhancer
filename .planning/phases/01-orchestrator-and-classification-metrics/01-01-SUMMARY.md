---
phase: 01-orchestrator-and-classification-metrics
plan: 01
subsystem: metrics
tags: [puppet, orchestrator, classifier, prometheus, ssl, epp]

requires: []
provides:
  - Orchestrator job and plan metric collectors with SSL client cert auth
  - Node group classification and class usage metric collectors
  - Feature flag parameters (enable_orchestrator_metrics, enable_classification_metrics)
  - fetch_json_from_orchestrator HTTP client with VERIFY_PEER
  - Conditional header_metrics merge pattern for feature-gated metric types
affects: [02-dashboard-generation, 03-self-monitoring]

tech-stack:
  added: []
  patterns:
    - "Feature-gated collectors via Boolean params and conditional collect_with_error_handling blocks"
    - "SSL client cert HTTP client reusing existing retry/backoff pattern"
    - "header_metrics hash restructured to base hash plus conditional merge! blocks"

key-files:
  created: []
  modified:
    - manifests/init.pp
    - templates/puppet_data_connector_enhancer.epp
    - data/common.yaml
    - spec/classes/puppet_data_connector_enhancer_spec.rb

key-decisions:
  - "Manual patch application rather than git apply due to self_service_graphs branch divergence"
  - "Spec file tests inserted before resource ordering context to maintain test structure"

patterns-established:
  - "Feature-gated metric collectors: Boolean param in manifest, conditional block in generate_metrics, conditional merge! in header_metrics"
  - "SSL client cert auth via fetch_json_from_orchestrator reused for both Orchestrator and Classifier APIs"

requirements-completed: [ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05]

duration: 6min
completed: 2026-04-05
---

# Phase 1 Plan 1: Orchestrator and Classification Metrics Summary

**PE Orchestrator job/plan collectors and node group classification metrics with SSL client cert auth, feature-gated via Boolean parameters**

## Performance

- **Duration:** 6 min 28s
- **Started:** 2026-04-05T07:29:13Z
- **Completed:** 2026-04-05T07:35:41Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Three new Puppet parameters (enable_orchestrator_metrics, orchestrator_jobs_limit, enable_classification_metrics) with docs, examples, typed declarations, and Hiera defaults
- Four collector methods ported from feature/orchestrator-metrics: orchestrator jobs, orchestrator plans, node groups, class usage (emitting 13 metric types total)
- SSL client certificate HTTP client (fetch_json_from_orchestrator) with VERIFY_PEER, retry with exponential backoff
- Restructured header_metrics hash with conditional merge! blocks for feature-gated metric type headers
- rspec-puppet tests for orchestrator and classification parameter compilation and template content

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate per-file patches** - no commit (patches are working artifacts in /tmp)
2. **Task 2: Apply patches to manifests/init.pp and data/common.yaml** - `c443475` (feat)
3. **Task 3: Apply patches to EPP template and spec tests** - `65840b1` (feat)

## Files Created/Modified

- `manifests/init.pp` - Three new parameters with docs, examples, typed declarations, and EPP hash keys
- `templates/puppet_data_connector_enhancer.epp` - Four collector methods, SSL HTTP client, base URL helpers, feature flag conditionals, config keys, restructured header_metrics
- `data/common.yaml` - Hiera defaults for all three new parameters (disabled by default)
- `spec/classes/puppet_data_connector_enhancer_spec.rb` - Test contexts for orchestrator and classification parameter compilation

## Decisions Made

- Manual patch application (not git apply) because self_service_graphs branch diverged from main with custom_queries code at all four insertion points
- Spec file conflict resolved by reverting git apply --3way output and manually inserting test contexts before the resource ordering context block
- Kept all existing custom_queries tests intact alongside new orchestrator/classification tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added spec file tests as part of Task 3**

- **Found during:** Task 3 (EPP template application)
- **Issue:** The plan defined only 3 tasks but the spec file was listed in files_modified and the overall verification requires all four files to contain changes. The spec tests are required for the TEST-02 phase requirement.
- **Fix:** Applied the spec file changes from the feature branch patch as part of Task 3, resolving merge conflicts manually by keeping both custom_queries and orchestrator/classification test contexts.
- **Files modified:** spec/classes/puppet_data_connector_enhancer_spec.rb
- **Verification:** No conflict markers, all test contexts present
- **Committed in:** 65840b1 (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Spec tests were always intended (listed in files_modified and required by TEST-02). No scope creep.

## Issues Encountered

- git apply --3way on the spec file produced 4 conflict blocks because the feature branch patch context lines referenced code from main that had been replaced by custom_queries tests on self_service_graphs. Resolved by reverting and manually inserting the test contexts at the correct location.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All orchestrator and classification metric collectors are in place and feature-gated
- Ready for Plan 02 (spec tests and verification) or Phase 2 work
- No blockers identified

## Self-Check: PASSED

All 4 modified files exist on disk. Both task commits (c443475, 65840b1) verified in git log.

---
*Phase: 01-orchestrator-and-classification-metrics*
*Completed: 2026-04-05*
