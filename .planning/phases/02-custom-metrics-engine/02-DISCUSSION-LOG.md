# Phase 2: Custom Metrics Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 02-custom-metrics-engine
**Areas discussed:** Schema validation depth, Name collision handling, Row limit behaviour, PQL quote escaping

---

## Schema Validation Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Validate-and-warn | Validate upfront, log warnings, skip invalid, collect valid | ✓ |
| Validate-and-fail | Any invalid definition aborts entire custom collection | |
| Strict catalog-time | Puppet function validates YAML at compile time | |

**User's choice:** Validate-and-warn
**Notes:** Mirrors existing collect_with_error_handling pattern

| Option | Description | Selected |
|--------|-------------|----------|
| name + endpoint + type + help | All four required, endpoint-specific fields per type | ✓ |
| name + endpoint only | Minimal, type defaults to gauge, help auto-generated | |
| name + endpoint + type | Three required, help optional | |

**User's choice:** name + endpoint + type + help

| Option | Description | Selected |
|--------|-------------|----------|
| Strict — four types only | Unknown types rejected | |
| Open — warn but allow unknown | Unknown types pass with warning | |
| Add a fifth — nodes | Add nodes convenience type | ✓ |

**User's choice:** Five types (fact, pql, resource, inventory, nodes). User asked about additional PE endpoints — confirmed PQL covers everything, but nodes endpoint is common enough for convenience.

| Option | Description | Selected |
|--------|-------------|----------|
| Structured summary | Validate all first, log single summary | ✓ |
| Individual log lines | Log each issue as found | |

**User's choice:** Structured summary

| Option | Description | Selected |
|--------|-------------|----------|
| Separate method | validate_custom_metric_definitions returning valid/errors | ✓ |
| Inline in collect_custom_metrics | Keep validation within existing method | |

**User's choice:** Separate testable method

---

## Name Collision Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Enforce prefix + warn on collision | Require puppet_custom_ prefix, warn and skip on collision | ✓ |
| Warn only, no prefix | Check against built-in list, warn but collect | |
| Auto-prefix if missing | Silently prepend puppet_custom_ | |

**User's choice:** Enforce prefix + warn on collision

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — catch and warn | Duplicate names: warn, skip second | ✓ |
| No — last definition wins | Allow duplicates silently | |

**User's choice:** Catch and warn on duplicates

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded constant | BUILTIN_METRIC_PREFIXES frozen Set | ✓ |
| Dynamic from header_metrics | Build list at runtime | |

**User's choice:** Hardcoded constant

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — validate format | Check /^[a-z][a-z0-9_]*$/ | ✓ |
| No — pass through | Let Prometheus handle | |

**User's choice:** Validate metric name format

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — validate labels too | Check label names against Prometheus rules | ✓ |
| No — metric names only | Only validate metric names | |

**User's choice:** Validate labels too

---

## Row Limit Behaviour

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable per-metric with global default | row_limit in YAML, global Puppet parameter default | ✓ |
| Mandatory per-metric | Every definition must specify row_limit | |
| Global only | Single parameter for all metrics | |

**User's choice:** Configurable per-metric with global default

| Option | Description | Selected |
|--------|-------------|----------|
| 500 rows | Conservative, covers most real-world cases | ✓ |
| 100 rows | Very conservative | |
| 1000 rows | Permissive | |

**User's choice:** 500 rows default

| Option | Description | Selected |
|--------|-------------|----------|
| API level where possible | Pass limit to PuppetDB API, fallback to Ruby | ✓ |
| Ruby-side only | Fetch all, truncate in Ruby | |

**User's choice:** API level where possible

| Option | Description | Selected |
|--------|-------------|----------|
| 0 means unlimited | Explicit opt-out | ✓ |
| Reject 0 as invalid | Force positive integer | |

**User's choice:** 0 means unlimited

---

## PQL Quote Escaping

| Option | Description | Selected |
|--------|-------------|----------|
| YAML file only for Phase 2 | Focus on custom_queries_file path, defer inline param | ✓ |
| Fix both paths now | Address EPP escaping for inline param too | |
| Deprecate inline parameter | Mark custom_queries as deprecated | |

**User's choice:** YAML file only for Phase 2

| Option | Description | Selected |
|--------|-------------|----------|
| No — let PuppetDB validate | Pass through, let API handle syntax | |
| Basic checks only | Empty strings, unbalanced quotes | ✓ |

**User's choice:** Basic checks only

| Option | Description | Selected |
|--------|-------------|----------|
| No — PuppetDB handles this | PQL isn't SQL, no injection risk | |
| Basic sanitisation | Reject semicolons and common SQL patterns | ✓ |

**User's choice:** Basic sanitisation — defence in depth

---

## Claude's Discretion

- Exact validation error message wording
- Nodes endpoint API parameter mapping
- Ruby-side truncation implementation details
- Specific SQL injection patterns to check

## Deferred Ideas

- EPP quote escaping for custom_queries inline parameter — polish phase/backlog
- Deprecating custom_queries parameter — considered, not actioned
- Ruby unit tests for collection logic — still deferred per Phase 1 D-08
- Full PQL syntax validation — PuppetDB handles this
