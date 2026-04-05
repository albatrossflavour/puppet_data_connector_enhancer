# Phase 2: Custom Metrics Engine - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the YAML-to-Prometheus pipeline with validation, safety guards, and dot-path extraction. Users can paste a PQL query into a YAML file and get a working Prometheus metric, with the module handling validation, safety, and formatting automatically. The core pipeline (four endpoint types, dot-path extraction, label/value extraction, HELP/TYPE headers) already exists on self_service_graphs — this phase adds the missing safety guardrails.

</domain>

<decisions>
## Implementation Decisions

### Schema Validation
- **D-01:** Validate-and-warn approach. Validate all definitions upfront before collection starts. Log warnings for each issue, skip invalid entries, collect valid ones. Mirrors the existing collect_with_error_handling pattern.
- **D-02:** Required fields per metric definition: name, endpoint, type, help. Endpoint-specific fields (pql_query, fact_name, resource_type) enforced per endpoint type.
- **D-03:** Five valid endpoint types: fact, pql, resource, inventory, nodes. Unknown types rejected with a warning during validation.
- **D-04:** Validation produces a structured summary log line: "3/5 custom metrics valid, 2 skipped (see warnings above)" rather than scattered individual warnings.
- **D-05:** Extract validation as a separate testable method (validate_custom_metric_definitions) that returns {valid: [...], errors: [...]}. Makes it independently testable for TEST-01 error scenarios.

### Name Collision Handling
- **D-06:** Enforce puppet_custom_ prefix on all custom metric names. If a name collides with a built-in metric, log a warning and skip that definition.
- **D-07:** Catch duplicate custom metric names within the YAML itself. Warn and skip the second definition.
- **D-08:** Built-in metric name list maintained as a hardcoded BUILTIN_METRIC_PREFIXES constant (frozen Set). Updated when new built-in metrics are added.
- **D-09:** Validate metric names against Prometheus naming rules (/^[a-z][a-z0-9_]*$/). Catches names that would be rejected by Prometheus.
- **D-10:** Validate label names against Prometheus rules too (lowercase, underscores, no __ prefix).

### Row Limit Behaviour
- **D-11:** Configurable per-metric with global default. Each metric definition can set row_limit in YAML. If omitted, use global default. Global default is a Puppet class parameter.
- **D-12:** Default row limit is 500 rows.
- **D-13:** Enforce row limits at the PuppetDB API level (using limit parameter) where possible. Fall back to Ruby-side truncation for endpoints that don't support it.
- **D-14:** row_limit: 0 means unlimited. Explicit opt-out for operators who understand the cardinality implications.

### PQL Quote Escaping
- **D-15:** Phase 2 focuses on the YAML file path (custom_queries_file) only. The custom_queries inline Puppet parameter has an EPP escaping risk but is deferred to a polish phase or backlog.
- **D-16:** Basic PQL checks: reject empty strings and unbalanced quotes. Let PuppetDB handle full PQL syntax validation via its error responses.
- **D-17:** Basic sanitisation for PQL queries: reject queries containing semicolons or common SQL injection patterns. Defence in depth even though PQL is not SQL.

### Claude's Discretion
- Exact validation error message wording
- How the nodes endpoint convenience type maps to PuppetDB API parameters
- Ruby-side truncation implementation details for the row limit fallback
- Specific SQL injection patterns to check for in basic sanitisation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing custom metrics implementation
- `templates/puppet_data_connector_enhancer.epp` lines 1011-1173 — Current collect_custom_metrics, collect_single_custom_metric, fetch_custom_metric_data, extract_labels, extract_value, resolve_json_path, collect_custom_metric_headers methods
- `manifests/init.pp` lines 178-179 — custom_queries and custom_queries_file parameters
- `manifests/init.pp` lines 233-248 — custom queries YAML file resource management

### Module structure
- `data/common.yaml` — Hiera defaults for new parameters (custom_queries_row_limit)
- `.planning/REQUIREMENTS.md` — CUST-01 through CUST-06, TEST-01 requirement definitions

### Phase 1 context
- `.planning/phases/01-orchestrator-and-classification-metrics/01-CONTEXT.md` — D-08: Ruby unit tests deferred until codebase stabilises

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `collect_custom_metrics` method: Already reads YAML, parses config, iterates definitions. Needs validation layer added before the iteration.
- `fetch_custom_metric_data` method: Handles four endpoint types with case/when. Adding nodes type is a new when clause.
- `resolve_json_path` method: Dot-path extraction already works for nested hashes and arrays. No changes needed.
- `collect_custom_metric_headers` method: Already generates HELP/TYPE from definition fields. Works as-is if type/help are required.
- `MetricsCollectionError` class: Custom exception with context attributes. Reusable for validation errors.
- `collect_with_error_handling` wrapper: Isolates per-collector failures. Custom metrics already wrapped.

### Established Patterns
- EPP template generates a complete Ruby script with baked-in config at compile time
- Feature flags via Boolean Puppet parameters with conditional collector invocation
- Env var overrides for all config values
- YAML.safe_load with permitted_classes: [] for safe parsing
- Per-collector error isolation via collect_with_error_handling

### Integration Points
- New Puppet parameter (custom_queries_row_limit) added to init.pp and passed through EPP hash
- Validation method inserted between YAML parsing and metric iteration in collect_custom_metrics
- BUILTIN_METRIC_PREFIXES constant added near other constants in the generated script
- Row limit parameter passed to fetch_json_from_puppetdb via params hash

</code_context>

<specifics>
## Specific Ideas

- The nodes endpoint type maps to /pdb/query/v4/nodes — same pattern as fact, resource, inventory convenience types
- PQL is not SQL, but basic sanitisation for semicolons and injection patterns is wanted as defence in depth
- Validation summary should give operators a quick picture of config health without trawling through individual warnings

</specifics>

<deferred>
## Deferred Ideas

- EPP quote escaping for the custom_queries inline parameter — deferred to polish phase or backlog
- Deprecating custom_queries parameter in favour of custom_queries_file — considered but not actioned
- Ruby unit tests for collection logic (D-08 from Phase 1) — still deferred until codebase stabilises
- PQL syntax validation beyond basic checks — PuppetDB handles this better than we can

</deferred>

---

*Phase: 02-custom-metrics-engine*
*Context gathered: 2026-04-05*
