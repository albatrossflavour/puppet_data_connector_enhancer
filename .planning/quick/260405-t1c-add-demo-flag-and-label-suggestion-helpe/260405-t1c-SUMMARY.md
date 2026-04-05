---
phase: quick-260405-t1c
plan: 01
subsystem: cli-metric-builder
tags: [demo, label-suggestion, cli, puppetdb]
dependency_graph:
  requires: [puppet_custom_metric_builder.epp]
  provides: [demo-mode, label-suggestion-engine]
  affects: [cli-metric-builder]
tech_stack:
  added: []
  patterns: [recursive-field-walker, field-categorisation]
key_files:
  created: []
  modified:
    - templates/puppet_custom_metric_builder.epp
decisions:
  - Demo mode reuses existing fetch_sample_data with configurable limit parameter
  - walk_structure capped at depth 3 to prevent stack overflow on nested PuppetDB responses
  - Boolean fields categorised as labels (valid Prometheus label values)
  - Interactive mode offers demo as opt-out (Y/n) rather than opt-in
metrics:
  duration: 114s
  completed: 2026-04-05
  tasks: 1/1
  files_modified: 1
---

# Quick Task 260405-t1c: Demo Flag and Label Suggestion Helper

CLI metric builder now shows raw PuppetDB data and suggests field paths for labels and values.

## What Changed

Added `--demo` flag and supporting label suggestion engine to `puppet_custom_metric_builder.epp`.
Users can now run `--demo --endpoint pql --pql-query "nodes { }"` to see the actual data shape
returned by PuppetDB before committing to label and value field paths.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add demo data display and label suggestion engine | b94c862 | templates/puppet_custom_metric_builder.epp |

## Implementation Details

New public methods:

- `demo_mode?` -- predicate for the `--demo` flag state
- `show_demo_data(defn)` -- fetches up to 5 rows, pretty-prints JSON, calls suggestion engine

New private methods:

- `suggest_labels_from_data(data)` -- categorises first row fields into labels, values, skipped
- `walk_structure(obj, prefix, strings, numerics, skipped, depth)` -- recursive hash walker, max depth 3
- `label_name_from_path(path)` -- converts dot-paths like `facts.os.name` to Prometheus label `name`
- `endpoint_supports_demo?(defn)` -- gates interactive demo offer based on available endpoint info

Flow changes:

- **Flag mode**: `--demo` shows data and suggestions, then exits cleanly (validation errors suppressed in demo mode)
- **Interactive mode**: after collecting endpoint-specific fields (step 3), offers "Run demo query to see data shape? [Y/n]" before asking for metric type, labels, and value paths
- `fetch_sample_data` now accepts optional `limit` parameter (default 3, demo uses 5)

## Threat Mitigations Applied

- T-quick-02: PQL validation runs before demo fetch (reuses existing `sanitise_pql_timestamp` and `validate_pql_query`)
- T-quick-03: `walk_structure` capped at depth 3, `fetch_sample_data` limited to 5 rows in demo mode

## Deviations from Plan

None. Plan executed exactly as written.

## Self-Check: PASSED

- [x] templates/puppet_custom_metric_builder.epp exists and modified
- [x] Commit b94c862 exists in git log
- [x] Ruby syntax check passes (with EPP substitution)
- [x] grep confirms all 6 new methods present
- [x] demo references count >= 10 (actual: 18)
