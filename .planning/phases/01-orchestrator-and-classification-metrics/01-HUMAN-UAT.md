---
status: partial
phase: 01-orchestrator-and-classification-metrics
source: [01-VERIFICATION.md]
started: 2026-04-05T07:57:28Z
updated: 2026-04-05T07:57:28Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Live Orchestrator Metrics Collection

expected: Apply with `enable_orchestrator_metrics => true`, trigger collection, check .prom output for all nine `puppet_orchestrator_*` metric names (5 job + 4 plan). SSL client cert mutual auth against live PE Orchestrator API on port 8143 produces real data.
result: [pending]

### 2. Live Classification Metrics Collection

expected: Apply with `enable_classification_metrics => true`, trigger collection, check for node group hierarchy in `puppet_node_group_edge` and class usage counts in `puppet_class_usage_total`. Classifier API on port 4433 returns meaningful hierarchy edges and node counts.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
