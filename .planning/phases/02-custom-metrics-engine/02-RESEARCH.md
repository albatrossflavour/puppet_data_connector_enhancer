# Phase 2: Custom Metrics Engine - Research

**Researched:** 2026-04-05
**Domain:** YAML validation, Prometheus metric safety, PuppetDB query API
**Confidence:** HIGH

## Summary

This phase adds safety guardrails around an existing custom metrics pipeline. The core collection logic (four endpoint types, dot-path JSON extraction, label/value extraction, HELP/TYPE headers) already exists in the EPP template. What is missing is validation before collection starts, name collision detection, row limit enforcement, PQL sanitisation, and a fifth endpoint type (`nodes`).

The work is almost entirely within the EPP template (`templates/puppet_data_connector_enhancer.epp`), with a small amount of Puppet manifest work (new `custom_queries_row_limit` parameter in `init.pp`) and Hiera defaults. The existing `collect_with_error_handling` pattern and `MetricsCollectionError` class provide the error isolation framework. PuppetDB v4 API supports `limit` as an HTTP query parameter, which makes server-side row limiting straightforward for all endpoint types.

**Primary recommendation:** Insert a `validate_custom_metric_definitions` method between YAML parsing and metric iteration in `collect_custom_metrics`. This method returns `{valid: [...], errors: [...]}` and handles all validation (schema, naming, collision, PQL sanitisation) in one pass before any API calls are made.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Validate-and-warn approach. Validate all definitions upfront before collection starts. Log warnings for each issue, skip invalid entries, collect valid ones. Mirrors the existing collect_with_error_handling pattern.
- **D-02:** Required fields per metric definition: name, endpoint, type, help. Endpoint-specific fields (pql_query, fact_name, resource_type) enforced per endpoint type.
- **D-03:** Five valid endpoint types: fact, pql, resource, inventory, nodes. Unknown types rejected with a warning during validation.
- **D-04:** Validation produces a structured summary log line: "3/5 custom metrics valid, 2 skipped (see warnings above)" rather than scattered individual warnings.
- **D-05:** Extract validation as a separate testable method (validate_custom_metric_definitions) that returns {valid: [...], errors: [...]}. Makes it independently testable for TEST-01 error scenarios.
- **D-06:** Enforce puppet_custom_ prefix on all custom metric names. If a name collides with a built-in metric, log a warning and skip that definition.
- **D-07:** Catch duplicate custom metric names within the YAML itself. Warn and skip the second definition.
- **D-08:** Built-in metric name list maintained as a hardcoded BUILTIN_METRIC_PREFIXES constant (frozen Set). Updated when new built-in metrics are added.
- **D-09:** Validate metric names against Prometheus naming rules (/^[a-z][a-z0-9_]*$/). Catches names that would be rejected by Prometheus.
- **D-10:** Validate label names against Prometheus rules too (lowercase, underscores, no __ prefix).
- **D-11:** Configurable per-metric with global default. Each metric definition can set row_limit in YAML. If omitted, use global default. Global default is a Puppet class parameter.
- **D-12:** Default row limit is 500 rows.
- **D-13:** Enforce row limits at the PuppetDB API level (using limit parameter) where possible. Fall back to Ruby-side truncation for endpoints that don't support it.
- **D-14:** row_limit: 0 means unlimited. Explicit opt-out for operators who understand the cardinality implications.
- **D-15:** Phase 2 focuses on the YAML file path (custom_queries_file) only. The custom_queries inline Puppet parameter has an EPP escaping risk but is deferred to a polish phase or backlog.
- **D-16:** Basic PQL checks: reject empty strings and unbalanced quotes. Let PuppetDB handle full PQL syntax validation via its error responses.
- **D-17:** Basic sanitisation for PQL queries: reject queries containing semicolons or common SQL injection patterns. Defence in depth even though PQL is not SQL.
- **D-18:** Detect hardcoded ISO8601 timestamps in PQL queries during validation. Warn the user that the query contains stale dates (likely pasted from the Infra Assistant chatbot), then strip the timestamp comparison clause before sending to PuppetDB.

### Claude's Discretion

- Exact validation error message wording
- How the nodes endpoint convenience type maps to PuppetDB API parameters
- Ruby-side truncation implementation details for the row limit fallback
- Specific SQL injection patterns to check for in basic sanitisation

### Deferred Ideas (OUT OF SCOPE)

- EPP quote escaping for the custom_queries inline parameter
- Deprecating custom_queries parameter in favour of custom_queries_file
- Ruby unit tests for collection logic (D-08 from Phase 1)
- PQL syntax validation beyond basic checks

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CUST-01 | User can define custom metrics via YAML config with four endpoint types (fact, pql, resource, inventory) | Existing `fetch_custom_metric_data` already handles these four types. Add `nodes` as fifth per D-03. Row limit integration via PuppetDB `limit` parameter. |
| CUST-02 | YAML config is validated at schema level (missing required fields, invalid endpoint types) | New `validate_custom_metric_definitions` method per D-05. Required fields per D-02. |
| CUST-03 | Custom metric names checked against built-in names, warning on collision | BUILTIN_METRIC_PREFIXES constant (frozen Set) per D-08. Full list of 30 built-in metric names documented below. |
| CUST-04 | Each custom metric has a configurable row limit | PuppetDB v4 API supports `limit` as HTTP query parameter. New Puppet param `custom_queries_row_limit` with default 500. |
| CUST-05 | EPP template correctly escapes PQL queries containing internal quotes | Deferred for inline parameter (D-15). YAML file path reads raw YAML so no EPP escaping needed, this requirement is satisfied by the file-based approach. |
| CUST-06 | Custom metrics support dot-path JSON extraction for nested values | Already implemented in `resolve_json_path`. No changes needed, but validation should check that label paths and value_field are non-empty strings. |
| TEST-01 | Tests cover custom metrics error scenarios (bad YAML, missing config, invalid schema) | rspec-puppet catalogue tests for parameter validation. Script-level validation testable via the extracted `validate_custom_metric_definitions` method. |

</phase_requirements>

## Standard Stack

No new libraries or dependencies are introduced. All work uses existing Ruby stdlib and the Puppet module framework already in the project.

### Core (existing, no changes)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| YAML (stdlib) | Ruby stdlib | Parse custom_queries YAML file | Already used via `YAML.safe_load` [VERIFIED: codebase line 1021] |
| Set (stdlib) | Ruby stdlib | Deduplication, built-in metric name lookup | Already used for `@seen_metrics` [VERIFIED: codebase line 48] |
| URI (stdlib) | Ruby stdlib | HTTP query parameter encoding for `limit` | Already used in `fetch_json_from_puppetdb` [VERIFIED: codebase line 193-194] |

### Supporting (existing, no changes)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rspec-puppet | via puppetlabs_spec_helper ~> 8.0 | Catalogue compilation tests | TEST-01 parameter validation tests [VERIFIED: Gemfile] |
| puppet-lint | via voxpupuli-puppet-lint-plugins ~> 5.0 | Manifest linting | After modifying init.pp [VERIFIED: CLAUDE.md] |

### New Puppet Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `custom_queries_row_limit` | `Integer[0]` | 500 | Global default row limit for custom metrics (0 = unlimited) |

**Installation:** None required. All dependencies already present.

## Architecture Patterns

### Where the changes go

```
manifests/
  init.pp                    # Add custom_queries_row_limit parameter, pass to EPP
templates/
  puppet_data_connector_enhancer.epp   # Bulk of work: validation, row limits, nodes endpoint
  custom_queries.yaml.epp    # Add row_limit field support
data/
  common.yaml                # Add default for custom_queries_row_limit
spec/
  classes/puppet_data_connector_enhancer_spec.rb  # TEST-01 rspec-puppet tests
```

### Pattern 1: Validate-Then-Collect (D-01, D-05)

**What:** All metric definitions are validated upfront before any API calls are made. Invalid entries are logged and skipped. A summary line reports the validation result.
**When to use:** Any time user-provided configuration drives a collection loop.
**Example:**

```ruby
# Source: Codebase pattern from collect_custom_metrics (line 1011-1038)
# New method inserted between YAML parsing and iteration
def validate_custom_metric_definitions(definitions)
  valid = []
  errors = []

  seen_names = Set.new

  definitions.each_with_index do |defn, idx|
    issues = validate_single_definition(defn, idx, seen_names)
    if issues.empty?
      valid << defn
      seen_names.add(defn['name'])
    else
      issues.each { |msg| @logger.warn(msg) }
      errors.concat(issues)
    end
  end

  @logger.info(
    "#{valid.length}/#{definitions.length} custom metrics valid, " \
    "#{definitions.length - valid.length} skipped" \
    "#{errors.empty? ? '' : ' (see warnings above)'}"
  )

  { valid: valid, errors: errors }
end
```

[VERIFIED: Pattern mirrors existing `collect_with_error_handling` approach in codebase]

### Pattern 2: PuppetDB API-Level Row Limiting (D-13)

**What:** Pass `limit` as an HTTP query parameter to PuppetDB, so the database handles truncation rather than fetching all rows and discarding.
**When to use:** All endpoint types (fact, pql, resource, inventory, nodes).
**Example:**

```ruby
# Source: PuppetDB v4 API paging docs
# https://www.puppet.com/docs/puppetdb/7/api/query/v4/paging.html
params['limit'] = row_limit.to_s if row_limit && row_limit > 0
```

[CITED: https://www.puppet.com/docs/puppetdb/7/api/query/v4/paging.html]

For PQL queries, the `limit` clause can also be embedded in the PQL string itself. However, since the user provides the PQL query, adding the `limit` as an HTTP parameter is cleaner and does not require parsing/modifying the user's PQL string.

**Ruby-side fallback:** If the API response returns more rows than expected (possible if PQL query already has its own limit), truncate with `rows = rows.first(row_limit)`.

### Pattern 3: Constant-Based Built-in Metric Registry (D-08)

**What:** A frozen Set of all built-in metric name prefixes, used for collision detection.
**When to use:** During validation, before any collection.

```ruby
# Place near other constants at class level
BUILTIN_METRIC_PREFIXES = Set.new([
  'puppet_configuration_version',
  'puppet_node_count',
  'puppet_state_overview',
  'puppet_node_os',
  'puppet_node_os_count',
  'puppet_infra_assistant_tokens_total',
  'puppet_node_trusted',
  'puppet_patch_run',
  'puppet_restart_required',
  'puppet_patching_data',
  'puppet_patching_blocked',
  'puppet_patching_group',
  'puppet_patching_stats',
  'puppet_patching_groups',
  'puppet_cis_compliance_score',
  'puppet_scm_export_success',
  'puppet_scm_export_last_run_timestamp',
  'puppet_scm_export_last_success_timestamp',
  'puppet_scm_export_duration_seconds',
  'puppet_scm_export_nodes_count',
  'puppet_scm_export_info',
  'puppet_infrastructure_config',
  'puppet_exporter_collection_failed',
  'puppet_exporter_scrape_duration_seconds',
  'puppet_exporter_scrape_success',
  'puppet_exporter_last_scrape_timestamp',
  'puppet_orchestrator_job_info',
  'puppet_orchestrator_job_duration_seconds',
  'puppet_orchestrator_job_start_timestamp',
  'puppet_orchestrator_job_node_count',
  'puppet_orchestrator_job_status_total',
  'puppet_orchestrator_plan_info',
  'puppet_orchestrator_plan_duration_seconds',
  'puppet_orchestrator_plan_start_timestamp',
  'puppet_orchestrator_plan_status_total',
  'puppet_node_group_info',
  'puppet_node_group_edge',
  'puppet_class_usage_total',
]).freeze
```

[VERIFIED: All metric names extracted from codebase grep of `build_metric` and `add_metric` calls]

### Pattern 4: Nodes Endpoint Type (D-03, Claude's Discretion)

**What:** The `nodes` convenience endpoint maps to `/pdb/query/v4/nodes`, returning node metadata (certname, deactivated, expired, catalog_timestamp, etc.).
**Recommendation:**

```ruby
when 'nodes'
  uri = "#{puppetdb_base_url}/pdb/query/v4/nodes"
  params = {}
  params['query'] = filter if filter
  params['limit'] = row_limit.to_s if row_limit && row_limit > 0
  fetch_json_from_puppetdb(uri, params) || []
```

[CITED: https://www.puppet.com/docs/puppetdb/7/api/query/v4/paging.html]

### Anti-Patterns to Avoid

- **Validating during collection:** Do not validate each metric definition inside `collect_single_custom_metric`. Validation must happen upfront (D-01) so operators get the full picture before any API calls are made.
- **Modifying user PQL queries beyond timestamp stripping:** The PQL query is the user's responsibility. Only strip stale timestamps (D-18) and reject obviously dangerous patterns (D-17). Do not attempt to parse or rewrite PQL.
- **Hardcoding the row limit:** Always use the per-metric `row_limit` with fallback to the global `custom_queries_row_limit` config value. Never use a magic number.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PQL syntax validation | Custom PQL parser | PuppetDB error responses | PQL grammar is complex, PuppetDB already validates and returns clear error messages [ASSUMED] |
| Prometheus metric name validation | Complex regex library | Simple `/^[a-z][a-z0-9_]*$/` regex | Prometheus naming rules are well-defined and simple enough for a regex [CITED: https://prometheus.io/docs/concepts/data_model/] |
| Row limiting at API level | Ruby-side pagination | PuppetDB `limit` HTTP parameter | Server-side limiting avoids transferring unnecessary data [CITED: PuppetDB paging docs] |
| YAML parsing | Custom parser | `YAML.safe_load` with `permitted_classes: []` | Already in use, handles safe deserialization [VERIFIED: codebase line 1021] |

## Common Pitfalls

### Pitfall 1: PQL Queries with Embedded Limit Clauses

**What goes wrong:** User's PQL query already contains a `limit` clause, and we add another `limit` HTTP parameter. PuppetDB may ignore one or apply both inconsistently.
**Why it happens:** Users copy PQL from the chatbot which may include limit clauses.
**How to avoid:** The HTTP `limit` parameter takes precedence over PQL-embedded limits. Document this behaviour. If a user's PQL has its own limit, the lower of the two applies. Apply Ruby-side truncation as a safety net regardless.
**Warning signs:** Metric emits fewer rows than expected despite row_limit being higher.

### Pitfall 2: Stale ISO8601 Timestamps in Chatbot PQL (D-18)

**What goes wrong:** User pastes PQL from the Infra Assistant chatbot containing hardcoded timestamps like `report_timestamp > "2026-03-15T00:00:00.000Z"`. The query returns nothing after a few days because no new data matches the stale date.
**Why it happens:** The chatbot generates point-in-time queries for investigation. Users paste these verbatim into ongoing collection config.
**How to avoid:** During validation, scan PQL queries for ISO8601 patterns (`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}`). Warn and strip the timestamp comparison clause.
**Warning signs:** Custom metric suddenly returns zero rows after initially working.

### Pitfall 3: EPP Quote Escaping in Inline Parameter

**What goes wrong:** PQL queries containing double quotes (e.g., `["=", "certname", "node1"]`) break the EPP template rendering when passed via the `custom_queries` inline Puppet parameter.
**Why it happens:** The `custom_queries.yaml.epp` template wraps values in double quotes without escaping.
**How to avoid:** Deferred to a polish phase (D-15). For Phase 2, the YAML file path approach avoids this entirely since `YAML.safe_load` reads the file directly without EPP interpolation.
**Warning signs:** Puppet catalogue compilation fails with syntax errors in the generated script.

### Pitfall 4: Cardinality Explosion from Unbounded Labels

**What goes wrong:** A custom metric with labels extracted from high-cardinality fields (e.g., certname on a 10,000-node estate) creates excessive time series.
**Why it happens:** Row limit controls the number of API result rows, but each row can still produce a unique label combination.
**How to avoid:** Row limit (D-11/D-12) is the primary guard. Document that operators should understand label cardinality before setting `row_limit: 0`.
**Warning signs:** Prometheus scrape duration increases significantly, Prometheus memory usage spikes.

### Pitfall 5: Metric Name Prefix Enforcement Edge Cases

**What goes wrong:** User defines a metric named `puppet_custom_nodes` and then another named `puppet_custom_nodes` (duplicate). Or names like `puppet_custom_` (empty suffix) pass the prefix check but are meaningless.
**Why it happens:** Prefix check alone is insufficient without length and uniqueness validation.
**How to avoid:** Combine prefix enforcement (D-06) with: minimum length check (prefix + at least one character), Prometheus naming regex (D-09), and duplicate detection (D-07).
**Warning signs:** Validation passes but Prometheus rejects the metric, or silent metric overwriting.

## Code Examples

### Validation Method Structure

```ruby
# Source: Design based on D-01 through D-10, D-16 through D-18
def validate_single_definition(defn, index, seen_names)
  errors = []
  label = "Custom metric definition ##{index + 1}"

  # Schema validation (D-02)
  %w[name endpoint type help].each do |field|
    errors << "#{label}: missing required field '#{field}'" unless defn[field] && !defn[field].to_s.strip.empty?
  end
  return errors unless errors.empty?  # Can't validate further without required fields

  name = defn['name']

  # Prometheus naming rules (D-09)
  unless name.match?(%r{^[a-z][a-z0-9_]*$})
    errors << "#{label} '#{name}': invalid metric name (must match /^[a-z][a-z0-9_]*$/)"
  end

  # Prefix enforcement (D-06)
  unless name.start_with?('puppet_custom_')
    errors << "#{label} '#{name}': must start with 'puppet_custom_' prefix"
  end

  # Built-in collision detection (D-06)
  if BUILTIN_METRIC_PREFIXES.include?(name)
    errors << "#{label} '#{name}': collides with built-in metric name"
  end

  # Duplicate detection (D-07)
  if seen_names.include?(name)
    errors << "#{label} '#{name}': duplicate metric name (already defined)"
  end

  # Endpoint type validation (D-03)
  valid_endpoints = %w[fact pql resource inventory nodes]
  unless valid_endpoints.include?(defn['endpoint'])
    errors << "#{label} '#{name}': unknown endpoint '#{defn['endpoint']}' (valid: #{valid_endpoints.join(', ')})"
  end

  # Endpoint-specific field validation (D-02)
  case defn['endpoint']
  when 'fact'
    errors << "#{label} '#{name}': fact endpoint requires 'fact_name'" unless defn['fact_name']
  when 'pql'
    errors << "#{label} '#{name}': pql endpoint requires 'pql_query'" unless defn['pql_query']
    errors.concat(validate_pql_query(defn['pql_query'], label, name)) if defn['pql_query']
  when 'resource'
    errors << "#{label} '#{name}': resource endpoint requires 'resource_type'" unless defn['resource_type']
  end

  # Prometheus type validation
  valid_types = %w[gauge counter histogram summary untyped]
  unless valid_types.include?(defn['type'])
    errors << "#{label} '#{name}': invalid metric type '#{defn['type']}' (valid: #{valid_types.join(', ')})"
  end

  # Label name validation (D-10)
  if defn['labels'].is_a?(Hash)
    defn['labels'].each_key do |label_name|
      unless label_name.match?(%r{^[a-z][a-z0-9_]*$}) && !label_name.start_with?('__')
        errors << "#{label} '#{name}': invalid label name '#{label_name}'"
      end
    end
  end

  errors
end
```

[VERIFIED: Pattern consistent with existing codebase conventions]

### PQL Sanitisation (D-16, D-17, D-18)

```ruby
# Source: Design based on D-16, D-17, D-18
DANGEROUS_PQL_PATTERNS = [
  /;/,                              # Semicolons
  /\b(DROP|DELETE|INSERT|UPDATE|ALTER|TRUNCATE)\b/i,  # SQL-like DDL/DML
  /--/,                             # SQL comments
  %r{/\*},                          # Block comments
].freeze

ISO8601_TIMESTAMP_PATTERN = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z?/

def validate_pql_query(query, label, name)
  errors = []

  # Empty string check (D-16)
  if query.strip.empty?
    errors << "#{label} '#{name}': pql_query cannot be empty"
    return errors
  end

  # Unbalanced quotes (D-16)
  if query.count('"').odd? || query.count("'").odd?
    errors << "#{label} '#{name}': pql_query has unbalanced quotes"
  end

  # Dangerous patterns (D-17)
  DANGEROUS_PQL_PATTERNS.each do |pattern|
    if query.match?(pattern)
      errors << "#{label} '#{name}': pql_query contains suspicious pattern '#{pattern.source}'"
    end
  end

  errors
end

def sanitise_pql_timestamp(query, name)
  # D-18: Detect and strip hardcoded timestamps
  if query.match?(ISO8601_TIMESTAMP_PATTERN)
    @logger.warn(
      "Custom metric '#{name}': PQL query contains hardcoded timestamp " \
      "(likely pasted from chatbot). Stripping timestamp comparison."
    )
    # Strip common timestamp comparison patterns
    # e.g., 'and report_timestamp > "2026-03-15T00:00:00.000Z"'
    # e.g., 'and producer_timestamp < "2026-03-15T00:00:00.000Z"'
    sanitised = query.gsub(
      /\s+and\s+\w+_timestamp\s*[<>=!]+\s*"[^"]*"/i,
      ''
    )
    sanitised.strip
  else
    query
  end
end
```

[ASSUMED: Timestamp stripping regex covers common chatbot output patterns]

### Row Limit Integration in fetch_custom_metric_data

```ruby
# Source: Design based on D-11, D-12, D-13, D-14
def fetch_custom_metric_data(defn)
  endpoint = defn['endpoint']
  filter = defn['filter']
  row_limit = defn['row_limit'] || @config[:custom_queries_row_limit] || 500

  # ... existing case/when for endpoint types ...
  # Add to each branch:
  params['limit'] = row_limit.to_s if row_limit.positive?

  rows = fetch_json_from_puppetdb(uri, params) || []

  # Ruby-side safety net (D-13 fallback)
  if row_limit.positive? && rows.length > row_limit
    @logger.warn("Custom metric '#{defn['name']}': truncating #{rows.length} rows to #{row_limit}")
    rows = rows.first(row_limit)
  end

  rows
end
```

[VERIFIED: `fetch_json_from_puppetdb` passes params as URI query string, PuppetDB accepts `limit` parameter]

### Updated collect_custom_metrics with Validation

```ruby
# Source: Design based on D-01, D-04, D-05
def collect_custom_metrics
  config_file = @config[:custom_queries_file]

  unless File.exist?(config_file)
    @logger.debug("Custom queries config file not found: #{config_file}")
    return
  end

  begin
    yaml_content = File.read(config_file)
    config = YAML.safe_load(yaml_content, permitted_classes: [])
  rescue Psych::SyntaxError => e
    @logger.error("Failed to parse custom queries YAML: #{e.message}")
    raise MetricsCollectionError.new("Invalid custom queries YAML: #{e.message}", config_file)
  rescue StandardError => e
    @logger.error("Failed to read custom queries file: #{e.message}")
    raise MetricsCollectionError.new("Cannot read custom queries file: #{e.message}", config_file)
  end

  return unless config && config['metrics'].is_a?(Array)

  # Validate all definitions upfront (D-01, D-05)
  result = validate_custom_metric_definitions(config['metrics'])
  @custom_metric_definitions = result[:valid]

  # Sanitise PQL timestamps in valid definitions (D-18)
  @custom_metric_definitions.each do |defn|
    next unless defn['endpoint'] == 'pql' && defn['pql_query']
    defn['pql_query'] = sanitise_pql_timestamp(defn['pql_query'], defn['name'])
  end

  @custom_metric_definitions.each do |defn|
    collect_single_custom_metric(defn)
  end

  @logger.info("Processed #{@custom_metric_definitions.length} custom metric definitions")
end
```

[VERIFIED: Follows existing `collect_custom_metrics` structure at codebase line 1011-1038]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No validation | Validate-and-warn upfront | This phase | Invalid configs caught before API calls |
| No row limit | PuppetDB `limit` parameter | This phase | Prevents cardinality explosion |
| 4 endpoint types | 5 endpoint types (+ nodes) | This phase | Users can query node metadata directly |
| Raw PQL passthrough | Basic PQL sanitisation | This phase | Defence in depth against injection |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Timestamp stripping regex covers common chatbot PQL patterns | Code Examples (D-18) | Timestamps not stripped, queries return stale data. Low risk: warning still logged. |
| A2 | PuppetDB returns clear error messages for invalid PQL | Don't Hand-Roll | If PQL errors are opaque, users get poor feedback. Mitigation: wrap in error handler with context. |
| A3 | `limit` HTTP parameter takes precedence when PQL also has `limit` clause | Pitfall 1 | Double-limiting could behave unexpectedly. Mitigation: Ruby-side truncation as safety net. |

## Open Questions

1. **Prometheus metric type validation scope**
   - What we know: Common types are gauge, counter, histogram, summary, untyped
   - What is unclear: Whether to allow histogram and summary since the module only emits simple gauge/counter style metrics
   - Recommendation: Allow all valid Prometheus types in validation but note that only gauge and counter produce meaningful output from this module

2. **Row limit interaction with PQL limit clauses**
   - What we know: PuppetDB supports both HTTP `limit` parameter and PQL `limit` clause
   - What is unclear: Exact precedence when both are present
   - Recommendation: Use HTTP `limit` parameter only (do not modify user PQL). Apply Ruby-side truncation as belt-and-braces.

## Sources

### Primary (HIGH confidence)

- Codebase: `templates/puppet_data_connector_enhancer.epp` lines 1011-1173 (existing custom metrics pipeline)
- Codebase: `manifests/init.pp` lines 178-179, 233-248 (custom queries parameters and file management)
- Codebase: `templates/custom_queries.yaml.epp` (YAML template for inline parameter)
- Codebase: `data/common.yaml` (Hiera defaults)
- Codebase: `spec/classes/puppet_data_connector_enhancer_spec.rb` (existing rspec-puppet tests)

### Secondary (MEDIUM confidence)

- [PuppetDB v4 Query Paging](https://www.puppet.com/docs/puppetdb/7/api/query/v4/paging.html) - `limit` and `offset` HTTP parameters
- [PuppetDB v4 PQL](https://www.puppet.com/docs/puppetdb/7/api/query/v4/pql.html) - PQL query language reference
- [Prometheus Data Model](https://prometheus.io/docs/concepts/data_model/) - Metric and label naming conventions

### Tertiary (LOW confidence)

- None

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - no new dependencies, all existing libraries
- Architecture: HIGH - extending existing patterns with well-understood validation logic
- Pitfalls: HIGH - based on direct codebase analysis and user workflow understanding

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable domain, no fast-moving dependencies)
