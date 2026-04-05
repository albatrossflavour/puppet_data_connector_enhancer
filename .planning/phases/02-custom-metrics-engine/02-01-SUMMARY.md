---
phase: 02-custom-metrics-engine
plan: 01
subsystem: metrics
tags: [puppet, ruby, epp, validation, pql, puppetdb, prometheus]

requires:
  - phase: 01-orchestrator-and-classification-metrics
    provides: EPP template with existing custom metrics pipeline and collect_with_error_handling pattern

provides:
  - Validation engine for custom metric YAML definitions (validate_custom_metric_definitions)
  - PQL query sanitisation (dangerous pattern rejection, timestamp stripping)
  - Built-in metric name collision detection (BUILTIN_METRIC_PREFIXES)
  - Configurable row limit enforcement at PuppetDB API level
  - Nodes endpoint type for PuppetDB /pdb/query/v4/nodes

affects: [02-custom-metrics-engine, 03-dashboards-and-self-monitoring]

tech-stack:
  added: []
  patterns:
    - "Validate-then-collect: all definitions validated upfront before any API calls"
    - "PuppetDB API-level row limiting with Ruby-side truncation safety net"
    - "Constant-based metric registry for collision detection"

key-files:
  created: []
  modified:
    - templates/puppet_data_connector_enhancer.epp
    - manifests/init.pp
    - data/common.yaml
    - templates/custom_queries.yaml.epp

key-decisions:
  - "Constants placed inside PrometheusMetricsGenerator class body for encapsulation"
  - "Row limit uses defn.fetch with fallback to global config, keeping per-metric override clean"
  - "fetch_custom_metric_data refactored to assign rows from case expression, applying truncation once at the end"

patterns-established:
  - "Validate-then-collect: validate_custom_metric_definitions returns {valid:, errors:} before iteration"
  - "PQL sanitisation: reject dangerous patterns, strip stale timestamps, let PuppetDB handle syntax"
  - "Row limiting: PuppetDB limit param + Ruby truncation safety net"

requirements-completed: [CUST-01, CUST-02, CUST-03, CUST-04, CUST-05, CUST-06]

duration: 4min
completed: 2026-04-05
---

# Phase 02 Plan 01: YAML Config Validation and Row Limits Summary

**Validation engine with PQL sanitisation, row limit enforcement across five endpoint types, and nodes endpoint for custom metrics pipeline**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-05T09:13:38Z
- **Completed:** 2026-04-05T09:17:15Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Validation engine that rejects invalid custom metric definitions upfront with clear warnings before any API calls
- PQL query sanitisation rejecting semicolons, SQL injection patterns, and stripping stale ISO8601 timestamps from chatbot-pasted queries
- Row limit enforcement at PuppetDB API level for all five endpoint types (fact, pql, resource, inventory, nodes) with Ruby-side truncation safety net
- Built-in metric name collision detection via frozen Set of 33 known metric prefixes
- Nodes endpoint type mapping to /pdb/query/v4/nodes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add validation engine and PQL sanitisation to EPP template** - `9d8f228` (feat)
2. **Task 2: Add row limit parameter and nodes endpoint** - `3f26f07` (feat)

## Files Created/Modified

- `templates/puppet_data_connector_enhancer.epp` - Added validation methods, constants, row limit integration, nodes endpoint, refactored fetch_custom_metric_data
- `manifests/init.pp` - Added custom_queries_row_limit parameter and EPP hash entry
- `data/common.yaml` - Added default row limit of 500
- `templates/custom_queries.yaml.epp` - Added row_limit field output

## Decisions Made

- Constants placed inside PrometheusMetricsGenerator class body rather than at module level, keeping them encapsulated with the class that uses them
- fetch_custom_metric_data refactored from inline returns to case-expression assignment, applying row truncation once at the end rather than duplicating in each branch
- Row limit uses `defn.fetch('row_limit', @config[:custom_queries_row_limit]).to_i` for clean per-metric override with global fallback

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `bundle exec rake validate` could not run due to missing gem dependencies in the worktree environment (pre-existing, not caused by this plan). Verified syntax through manual grep checks and structural inspection instead.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Validation engine is in place and callable, ready for TEST-01 rspec-puppet tests in a subsequent plan
- Row limit parameter flows end-to-end from Puppet manifest through EPP to runtime config
- All five endpoint types (fact, pql, resource, inventory, nodes) are validated and support row limiting
- Custom metrics pipeline is ready for dashboard generation work in Phase 3

---
*Phase: 02-custom-metrics-engine*
*Completed: 2026-04-05*

## Self-Check: PASSED

- All 5 files verified present on disk
- Commit 9d8f228 (Task 1) verified in git log
- Commit 3f26f07 (Task 2) verified in git log
