# Domain Pitfalls

**Domain:** Puppet metrics exporter with self-service PQL queries and Grafana dashboard generation
**Researched:** 2026-04-05
**Overall confidence:** MEDIUM (based on codebase analysis and domain experience; web search unavailable for verification)

## Critical Pitfalls

Mistakes that cause rewrites, production incidents, or unusable features.

### Pitfall 1: PQL Query Cardinality Explosion

**What goes wrong:** A user defines a PQL query that returns one row per node (or per
resource), with labels that create unique time series per certname. On an estate of 5,000
nodes, a single badly-scoped custom metric produces 5,000 time series. Three such metrics
and you have 15,000 new series. Prometheus ingestion rate climbs, memory usage spikes,
and the node exporter textfile collector starts taking measurable time to parse a file that
was previously trivial.

**Why it happens:** The current `collect_single_custom_metric` method (line 687) iterates
every row from PuppetDB and calls `add_metric` once per row. There is no limit on how many
rows a PQL query can return, and no cap on the number of unique label combinations. The
deduplication in `add_metric` (line 133) prevents duplicates within a single scrape, but
does nothing about cardinality.

**Consequences:**

- Prometheus storage growth, potentially hitting retention or disk limits
- Slow PromQL queries across dashboards (not just the offending one)
- Node exporter textfile collector performance degradation
- In extreme cases, Prometheus OOM kills

**Prevention:**

1. Add a `max_rows` parameter per custom metric definition (default: 500). Truncate results
   and log a warning when exceeded.
2. Add a global `max_total_custom_series` config (default: 5,000). Stop processing further
   custom metrics once the budget is exhausted.
3. Validate at YAML parse time: if a metric has no `labels` map but returns array data,
   warn that it will collapse to a single series (probably not what they wanted).
4. Document cardinality guidelines alongside the YAML format reference.

**Detection:** The self-monitoring metrics (total metrics per run) will show the count. Add
a `puppet_exporter_custom_metrics_rows_total` metric per definition so operators can spot
runaway queries before Prometheus notices.

**Phase relevance:** Must be addressed in the custom metrics YAML implementation phase,
not deferred.

### Pitfall 2: Unbounded PQL Query Execution Time

**What goes wrong:** A user pastes a PQL query from the chatbot that worked interactively
(returned in 2 seconds) but becomes expensive when run every 5 minutes by a systemd timer.
Queries involving subqueries, `in` clauses across large tables, or full resource scans can
take 30+ seconds on a loaded PuppetDB. The metrics collection script blocks on one slow
query, and the entire scrape either times out or runs so long that the next timer invocation
overlaps.

**Why it happens:** PQL queries that the chatbot returns are optimised for interactive
use ("show me which nodes have X"). They are not necessarily optimised for repeated
polling. PuppetDB does not have query cost estimation or a query planner that rejects
expensive queries. The current HTTP timeout (configurable, but shared across all
endpoints) is the only guard.

**Consequences:**

- Entire metrics collection stalls waiting for one custom query
- Systemd timer invocations overlap, creating duplicate load on PuppetDB
- Other built-in metrics (node counts, CIS scores) are delayed or missed
- PuppetDB itself degrades under repeated expensive queries

**Prevention:**

1. Add a per-query `timeout` field in the YAML config (default: 10 seconds), separate from
   the global HTTP timeout. Implement via `Net::HTTP#read_timeout` set per-request.
2. Add a `systemd` `TimeoutStopSec` or equivalent overall script timeout so the timer
   never overlaps (the existing systemd unit should have `Type=oneshot` with a
   `TimeoutStartSec` if it does not already).
3. Document which PQL patterns are safe for polling vs. which are expensive. Specifically
   warn about `in` subqueries and full resource table scans.
4. Consider adding a `--dry-run` mode that executes each custom query once and reports
   timing, so users can validate before deploying.

**Detection:** Self-monitoring metrics for API call duration per endpoint will surface this.
Add per-custom-metric timing so slow queries are individually identifiable.

**Phase relevance:** Custom metrics implementation phase. The timeout must be wired in from
the start, not bolted on later.

### Pitfall 3: Prometheus Metric Name Collisions

**What goes wrong:** A user defines a custom metric called `puppet_node_count` or
`puppet_state_overview`, which collides with the built-in metrics. The deduplication in
`add_metric` (line 133) silently drops the custom rows because the built-in metric with
the same name was already added to `@seen_metrics`. The user sees nothing in Grafana and
has no idea why.

**Why it happens:** The `collect_custom_metrics` method runs after all built-in collectors
(line 65), so built-in names win. There is no validation that custom metric names do not
collide with the built-in set. The user has no way to know what names are reserved.

**Consequences:**

- Silent data loss with no error or warning
- User confusion and debugging time
- Potential for subtle partial collisions where some label combinations match and others
  do not

**Prevention:**

1. Maintain a set of reserved metric name prefixes (`puppet_node_`, `puppet_state_`,
   `puppet_cis_`, `puppet_scm_`, `puppet_infra_`, `puppet_patch_`, `puppet_exporter_`).
2. At YAML parse time, reject custom metrics whose names start with a reserved prefix.
   Log a clear error message suggesting an alternative prefix.
3. Require custom metric names to start with `puppet_custom_` or a user-defined prefix.
   This namespacing prevents current and future collisions.

**Detection:** YAML validation at parse time, before any queries are executed.

**Phase relevance:** Custom metrics YAML implementation phase.

### Pitfall 4: Grafana Dashboard JSON Schema Drift

**What goes wrong:** The module generates Grafana dashboard JSON targeting a specific
schema version. Grafana releases a new version that changes panel schema, query format,
or datasource reference structure. Generated dashboards fail to import or render
incorrectly.

**Why it happens:** Grafana's dashboard JSON model is not formally versioned as a stable
API. The `schemaVersion` field in dashboard JSON increments with Grafana releases, and
while Grafana generally handles backward compatibility for imports, it does not guarantee
forward compatibility. If you generate JSON targeting `schemaVersion: 39` and the user
runs Grafana 11+ (which expects higher schema versions), panels may render with warnings
or missing features.

**Consequences:**

- Import errors in newer Grafana versions
- Panels render but with deprecated visualisation types
- Datasource references break if the user's datasource UID does not match

**Prevention:**

1. Use template variables for datasource references (`${DS_PROMETHEUS}` or the
   `__datasource` variable pattern) rather than hardcoded UIDs. The existing dashboard
   (`puppet_dashboards.json`) correctly uses `"type": "grafana"` for built-in sources but
   will need a configurable datasource name for Prometheus.
2. Target a conservative `schemaVersion` (e.g., 36-38, compatible with Grafana 9+).
3. Use only panel types that have been stable across releases: `timeseries`, `stat`,
   `table`, `gauge`. Avoid `graph` (deprecated since Grafana 8).
4. Document tested Grafana versions. Do not claim "works with any Grafana".

**Detection:** Include the target Grafana version range in the generated dashboard's
`description` field. Users will know if they are outside the tested range.

**Phase relevance:** Grafana dashboard generation phase.

## Moderate Pitfalls

### Pitfall 5: YAML Injection via Unsanitised PQL in Templates

**What goes wrong:** The `custom_queries.yaml.epp` template (line 14) renders user-provided
PQL queries directly into YAML using `<%= $metric['pql_query'] %>`. If a PQL query contains
YAML-special characters (colons, hashes, quotes, multiline strings), the generated YAML
file is invalid. The Ruby script then fails to parse it, and all custom metrics silently
stop working.

**Why it happens:** PQL queries routinely contain characters that are significant in YAML:
colons in function calls (`count()`), hashes in comments, quotes around string values. The
EPP template wraps the value in double quotes, but does not escape internal quotes. A PQL
query like `inventory[certname] { facts.os.name = "RedHat" }` produces
`pql_query: "inventory[certname] { facts.os.name = "RedHat" }"`, which is invalid YAML.

**Consequences:**

- All custom metrics fail (not just the one with the bad query)
- Error appears in systemd journal but not in Prometheus metrics
- User may not notice until dashboards go blank

**Prevention:**

1. Use YAML-safe escaping in the EPP template. Replace the raw `<%= %>` with proper
   escaping: either use Puppet's `to_yaml` function or manually escape quotes and special
   characters.
2. Better yet, use `YAML.dump` to generate the config file from structured data in the
   Puppet manifest, bypassing the EPP template entirely. Puppet's `inline_epp` with
   `to_yaml` would handle this correctly.
3. Add a validation step in the Ruby collector that provides specific, actionable error
   messages when YAML parsing fails (the current `Psych::SyntaxError` handler at line 669
   is good, but the error should indicate which metric definition is problematic).

**Detection:** The YAML parse error at line 669 catches this, but too late. Validate in
the Puppet manifest at catalog compilation time using a custom Puppet function.

**Phase relevance:** Custom metrics YAML implementation phase. This is a bug in the
existing partial implementation.

### Pitfall 6: Grafana Datasource UID Mismatch

**What goes wrong:** Generated dashboard JSON references a Prometheus datasource by UID
or name. The user's Grafana instance has the datasource configured with a different UID
or name. Every panel shows "No data" or "Datasource not found".

**Why it happens:** There is no standard Prometheus datasource UID across Grafana
installations. Some use `prometheus`, some use a generated UUID, some have multiple
Prometheus datasources.

**Consequences:**

- Dashboard imports but all panels are broken
- User must manually edit every panel's datasource reference
- On a complex dashboard with 20+ panels, this is tedious and error-prone

**Prevention:**

1. Use `"datasource": {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}` pattern in all
   panels. This prompts the user to select their datasource on import.
2. Alternatively, make the datasource name a configurable parameter in the Puppet module
   and template it into the JSON.
3. Include import instructions in the dashboard JSON's `description` field.

**Detection:** This is immediately visible on import. But providing good defaults prevents
the support burden.

**Phase relevance:** Grafana dashboard generation phase.

### Pitfall 7: Self-Monitoring Observer Effect

**What goes wrong:** Self-monitoring metrics (CPU, memory, wall time of the collection
script) add overhead to the very thing being measured. Measuring memory via
`/proc/self/status` or `ObjectSpace` at the wrong granularity adds garbage collection
pressure. Measuring CPU time per API call adds syscall overhead that inflates the timing
measurements.

**Why it happens:** The temptation is to instrument everything. But each measurement point
has a cost, and in a Ruby script running under Puppet's embedded Ruby (which is not the
fastest runtime), those costs compound.

**Consequences:**

- Collection script runs 10-20% slower than uninstrumented
- Memory measurements are inflated by the measurement infrastructure
- Timing measurements include measurement overhead

**Prevention:**

1. Measure coarsely: total wall time (already done at line 1104), total metrics emitted,
   and per-collector success/failure. Do not instrument individual API calls at the
   self-monitoring level (use debug logging for that).
2. For memory, take a single snapshot at the end using `GetProcessMem` or
   `/proc/self/status` (Linux only), not per-collector.
3. For API call counts/durations, use a simple counter hash incremented in
   `fetch_json_from_puppetdb`, not a separate instrumentation layer. The existing retry
   logic already has natural measurement points.

**Detection:** Compare collection duration with and without self-monitoring enabled.

**Phase relevance:** Self-monitoring implementation phase.

### Pitfall 8: Textfile Collector Atomic Write Failure

**What goes wrong:** The metrics script writes to the Prometheus node exporter textfile
collector directory. If the script crashes mid-write, Prometheus scrapes a partial file.
This produces parse errors in the node exporter, and the entire textfile is rejected,
losing all metrics (not just the ones being written).

**Why it happens:** The current `write_to_file` method (if it writes directly to the
output path) creates a window where the file is incomplete. Adding custom metrics
increases the write duration, widening this window.

**Consequences:**

- Complete metric loss for the duration of the partial file
- Node exporter logs fill with parse errors
- Prometheus shows gaps in all time series from this exporter

**Prevention:**

1. Write to a temporary file in the same directory, then `File.rename` (atomic on the
   same filesystem). Check if the existing implementation already does this. If it does,
   confirm the temp file is in the same directory as the target (cross-filesystem rename
   is not atomic).
2. Validate the output content before writing: ensure every line matches the Prometheus
   exposition format (metric name, optional labels, numeric value).

**Detection:** Monitor `node_textfile_scrape_error` metric from node exporter.

**Phase relevance:** Should be verified in the custom metrics phase, as the increased
output size makes this more likely.

### Pitfall 9: Orchestrator API Rate Limiting and Token Expiry

**What goes wrong:** The Orchestrator API (port 8143) and Classifier API (port 4433)
have different authentication and rate limiting characteristics than PuppetDB. The
metrics script, which was designed for PuppetDB's relatively tolerant API, hits rate
limits or authentication failures on these endpoints.

**Why it happens:** PuppetDB uses SSL client certificates and has no rate limiting.
The Orchestrator API may require RBAC tokens in addition to (or instead of) SSL client
certs, depending on the PE version and configuration. The Classifier API is less
commonly accessed programmatically and may have lower connection limits.

**Consequences:**

- Intermittent 401/403 errors on orchestrator metrics
- Connection refused or timeout on classifier API
- Partial metric collection where some endpoints work and others do not

**Prevention:**

1. Review the `feature/orchestrator-metrics` branch implementation for auth handling.
   Ensure it uses SSL client certs consistently and handles RBAC token auth if needed.
2. Add endpoint-specific error counters in the self-monitoring metrics so operators can
   distinguish PuppetDB failures from orchestrator failures.
3. Test against PE 2023.x and 2025.x (LTS and latest) as the API surface has changed.

**Detection:** Per-endpoint success/failure counters in self-monitoring.

**Phase relevance:** Orchestrator metrics merge phase.

## Minor Pitfalls

### Pitfall 10: PQL Query Syntax Differences Across PE Versions

**What goes wrong:** PQL syntax has evolved across PE versions. Queries that work on
PE 2023.x may not work on PE 2021.x (if still in use), and queries using newer PQL
features (like `group_by`, `avg`, `sum`) may fail on older PuppetDB versions.

**Prevention:** Document the minimum PE version required. Test custom metric examples
against PuppetDB v4 API (as noted in PROJECT.md constraints). Include PQL version
notes in the YAML format reference.

**Phase relevance:** Documentation phase.

### Pitfall 11: Dashboard JSON File Proliferation

**What goes wrong:** With "one dashboard per custom metric definition", a user with 20
custom metrics gets 20 separate dashboard JSON files. Importing and managing 20 dashboards
is worse than managing one dashboard with 20 panels.

**Prevention:**

1. Default to generating a single "Custom Metrics" dashboard containing panels for all
   defined custom metrics. This is more useful than one-dashboard-per-metric.
2. Optionally allow a `dashboard_group` field in the YAML so related metrics can be
   grouped onto the same dashboard.
3. Keep the generated dashboards as a folder structure with a README explaining how to
   bulk-import.

**Phase relevance:** Grafana dashboard generation phase. This is an architectural decision
that should be made before implementation, not after.

### Pitfall 12: Custom Metric Name Validation

**What goes wrong:** Prometheus metric names must match `[a-zA-Z_:][a-zA-Z0-9_:]*`.
Users define a metric name with hyphens, spaces, or dots (all common in infrastructure
naming). The metric is silently dropped or produces invalid exposition format.

**Prevention:**

1. Validate metric names at YAML parse time against the Prometheus naming regex.
2. Optionally auto-sanitise (replace `-` and `.` with `_`, strip invalid characters)
   with a warning.
3. The `build_metric` method (line 113) should validate the name, but currently does not.

**Detection:** Invalid metric names produce node exporter parse errors.

**Phase relevance:** Custom metrics YAML implementation phase.

### Pitfall 13: Label Value Sanitisation Edge Cases

**What goes wrong:** The existing `sanitize_label_value` method (line 107) handles
quotes, backslashes, and newlines. But PQL query results can contain arbitrary Unicode,
null bytes, or very long strings (e.g., a full `parameters` hash serialised as a string).
Very long label values bloat the textfile and can cause Prometheus to reject the series.

**Prevention:**

1. Truncate label values to a maximum length (128 characters is reasonable).
2. Strip null bytes and non-printable characters.
3. Document that label values are derived from PuppetDB data and may need the `value_field`
   to select specific fields rather than serialising entire hashes.

**Phase relevance:** Custom metrics implementation phase.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Custom metrics YAML | Cardinality explosion (P1), name collisions (P3), YAML injection (P5), name validation (P12) | Row limits, reserved prefixes, YAML escaping, name regex |
| Custom metrics execution | Unbounded query time (P2), label edge cases (P13) | Per-query timeout, label truncation |
| Orchestrator metrics merge | API auth differences (P9), PE version compat (P10) | Endpoint-specific error handling, version testing |
| Grafana dashboard generation | Schema drift (P4), datasource mismatch (P6), file proliferation (P11) | Conservative schema, variable datasource, single dashboard default |
| Self-monitoring | Observer effect (P7), textfile atomicity (P8) | Coarse measurements, atomic writes |
| Documentation | PQL version notes (P10), cardinality guidelines (P1) | Examples with safe patterns, explicit version requirements |

## Codebase-Specific Concerns

The following pitfalls are specific to issues already present in the codebase (from
CONCERNS.md) that will interact with the new features:

| Existing Concern | New Feature Interaction | Risk |
|-----------------|------------------------|------|
| SSL VERIFY_NONE | Orchestrator/Classifier APIs carry RBAC-sensitive data | Elevated: should fix before adding more API endpoints |
| `last_success_timestamp` overwrite on failure | Self-monitoring will add more failure modes | Elevated: pattern will be replicated if not fixed |
| No `unzip` dependency | Unrelated but indicates pattern of missing dependency declarations | Low: ensure new dependencies are declared |
| `lookup_in_parameter` for `$dropzone` | Custom queries file path will need similar defaulting | Medium: do not replicate the anti-pattern |

## Sources

- Codebase analysis: `/templates/puppet_data_connector_enhancer.epp` (custom metrics implementation)
- Codebase analysis: `/templates/custom_queries.yaml.epp` (YAML template)
- Codebase analysis: `/files/puppet_dashboards.json` (existing Grafana dashboard)
- Codebase analysis: `/.planning/codebase/CONCERNS.md` (known issues)
- Prometheus documentation: metric naming conventions and cardinality best practices
- Grafana documentation: dashboard JSON model and datasource variable patterns
- Domain experience: PuppetDB PQL query performance characteristics
- Confidence: MEDIUM (web search unavailable for external verification of current
  Grafana schema versions and PE API changes)

---

*Pitfalls audit: 2026-04-05*
