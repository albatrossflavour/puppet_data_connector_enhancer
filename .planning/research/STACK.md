# Technology Stack

**Project:** Puppet Data Connector Enhancer - Self-Service Graphs
**Researched:** 2026-04-05

## Recommended Stack

This is a brownfield project with a well-established stack. The recommendations
below focus on the new capabilities (custom metrics, dashboard generation,
self-monitoring) rather than re-evaluating existing technology choices, which are
constrained by the Puppet module ecosystem.

### Core Framework (Existing, No Changes)

| Technology | Version | Purpose | Why |
|---|---|---|---|
| Ruby | PE-embedded (2.7+) | Runtime for metrics collection script | Constrained by PE; only stdlib available on target nodes |
| Puppet DSL | PE 7.24-9.0 | Module manifests and resource management | This is a Puppet module; no alternative exists |
| EPP templates | Puppet 7+ | Template the Ruby collection script and config files | Already in use; preferred over ERB in modern Puppet |

**Confidence:** HIGH (direct codebase analysis)

### Prometheus Textfile Collector Format

| Technology | Version | Purpose | Why |
|---|---|---|---|
| OpenMetrics-compatible text format | Prometheus exposition format 0.0.4 | Metric output written to `.prom` files | Industry standard; already implemented in codebase |
| Atomic file writes (temp + rename) | N/A | Safe metric file updates | Already implemented; prevents partial reads by node_exporter |

The existing format implementation is correct and follows the specification.
Key format rules that matter for new custom metrics:

- `# HELP metric_name Description` before each metric family
- `# TYPE metric_name gauge|counter|histogram|summary` after HELP
- Metric lines: `metric_name{label="value"} numeric_value`
- Labels must be UTF-8, values must escape `\`, `"`, and newlines
- One HELP/TYPE block per metric name (no duplicates)
- File must end with a newline
- File extension must be `.prom` for node_exporter textfile collector

The codebase already handles all of this correctly via `build_metric` and
`generate_output_content`. The pattern to follow for new metrics is
well-established.

**What to watch for with custom metrics:** Users will define metric names in
YAML. These need validation against the Prometheus naming regex
`[a-zA-Z_:][a-zA-Z0-9_:]*` and label names against `[a-zA-Z_][a-zA-Z0-9_]*`.
The existing code does not validate metric names from custom queries YAML.

**Confidence:** HIGH (Prometheus exposition format is stable, well-documented,
and the existing implementation is correct)

### Grafana Dashboard JSON Generation

| Technology | Version | Purpose | Why |
|---|---|---|---|
| Ruby `JSON.generate` / `JSON.pretty_generate` | Ruby stdlib | Generate dashboard JSON from Ruby data structures | Zero dependencies; available on target nodes via PE Ruby |
| ERB/EPP templates | N/A | **Do NOT use** for dashboard generation | See rationale below |
| Grafonnet (jsonnet) | N/A | **Do NOT use** | See rationale below |

**The approach:** Generate Grafana dashboard JSON programmatically in Ruby using
plain data structures (hashes and arrays), not string templates.

**Why Ruby hashes, not ERB/EPP templates:**

- Dashboard JSON is deeply nested (5-10 levels). ERB templates for JSON become
  unreadable and fragile very quickly.
- Ruby hash literals map directly to JSON output. `JSON.pretty_generate(hash)`
  produces valid, readable dashboard JSON.
- Conditional panel inclusion, dynamic label mappings, and variable metric names
  are trivial with Ruby control flow.
- The existing static dashboards (in `files/`) demonstrate the target schema.
  Building the same structure in Ruby hashes is mechanical.

**Why not Grafonnet (jsonnet):**

- Grafonnet would add a build-time dependency on `jsonnet` or `go-jsonnet`.
- The target nodes have PE Ruby only. Generating dashboards must work within
  the existing Ruby runtime.
- Grafonnet is the right tool for organisations managing 50+ dashboards. This
  module generates a handful of dashboards per custom metric definition.
- The learning curve and toolchain complexity are not justified.

**Dashboard JSON schema to target:**

The existing dashboards use Grafana schema version 41 (Grafana 11.x compatible).
This is the version to target for generated dashboards. Key structural elements
the generator must produce:

```ruby
{
  # Top-level metadata
  "schemaVersion" => 41,
  "version" => 1,
  "editable" => true,
  "tags" => ["puppet", "custom"],
  "timezone" => "browser",
  "weekStart" => "monday",

  # Templating variables (reuse pattern from existing dashboards)
  "templating" => {
    "list" => [
      # DS_PROMETHEUS datasource variable (type: "datasource")
      # interval variable (type: "interval")
      # environment variable (type: "query", label_values)
    ]
  },

  # Panels array
  "panels" => [
    # Each panel: datasource, fieldConfig, gridPos, targets, type
  ]
}
```

**Panel types to support for auto-generated dashboards:**

| Metric Type | Default Panel | Rationale |
|---|---|---|
| Gauge (single value) | Stat panel | Shows current value prominently |
| Gauge (with labels) | Table panel + Time series | Table for current state, time series for trends |
| Counter | Time series with `rate()` | Counters need rate calculation to be useful |

**Confidence:** HIGH (based on analysis of 9 existing dashboard JSON files in
the codebase and Grafana's stable JSON model)

### Self-Monitoring Metrics

| Technology | Approach | Purpose | Why |
|---|---|---|---|
| Ruby `Process` module | `Process.times`, `Process.getrusage` | CPU and memory usage of collection script | Available in Ruby stdlib; no external dependency |
| `Time.now.to_f` | Wall clock timing per collection | Duration of each collection type | Already partially implemented (`@start_time`) |
| Internal counters | Ruby instance variables | API call counts, error counts, metrics collected | Follows Prometheus exporter conventions |

**Standard self-monitoring metrics for exporters:**

The existing codebase already has basic exporter health metrics. The PROJECT.md
requirements call for expanding these significantly. Following the Prometheus
exporter authoring guidelines, the standard pattern is:

| Metric Name | Type | Labels | Purpose |
|---|---|---|---|
| `puppet_exporter_scrape_duration_seconds` | gauge | (none) | Total collection time (EXISTS) |
| `puppet_exporter_scrape_success` | gauge | (none) | 1/0 success indicator (EXISTS) |
| `puppet_exporter_last_scrape_timestamp` | gauge | (none) | Unix timestamp of last run (EXISTS) |
| `puppet_exporter_collection_failed` | gauge | collection, endpoint, error | Per-collection failures (EXISTS) |
| `puppet_exporter_api_requests_total` | counter | endpoint, status | API call counts (NEW) |
| `puppet_exporter_api_duration_seconds` | gauge | endpoint | API call duration (NEW) |
| `puppet_exporter_metrics_collected_total` | gauge | collection | Metrics produced per collection type (NEW) |
| `puppet_exporter_process_cpu_seconds_total` | gauge | (none) | CPU time consumed (NEW) |
| `puppet_exporter_process_resident_memory_bytes` | gauge | (none) | RSS memory (NEW) |
| `puppet_exporter_collection_duration_seconds` | gauge | collection | Per-collection-type duration (NEW) |

**Important note on counter vs gauge for textfile collector:** The textfile
collector is scraped periodically by node_exporter. Each scrape reads the full
file. Because the collection script runs independently (via systemd timer) and
overwrites the file each run, `counter` type metrics will appear to reset on
each collection run. This is technically correct (Prometheus handles counter
resets) but can produce confusing graphs if the collection interval and scrape
interval are misaligned. Use `gauge` for "value at last collection" metrics
and reserve `counter` only for monotonically increasing values that genuinely
accumulate across runs (which, in a textfile collector context, means almost
nothing should be a counter). The existing codebase correctly uses `gauge` for
nearly everything, with only `puppet_infra_assistant_tokens_total` as a
counter (and that one comes from an upstream API that provides the running
total).

**Confidence:** HIGH (Prometheus exporter conventions are well-established;
existing codebase already follows the correct patterns)

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| `json` (Ruby stdlib) | N/A | Dashboard JSON generation and API response parsing | Always; already in use |
| `yaml` (Ruby stdlib) | N/A | Custom queries config parsing | Already in use for custom_queries.yaml |
| `fileutils` (Ruby stdlib) | N/A | Directory creation for dashboard output | Already in use |
| `optparse` (Ruby stdlib) | N/A | CLI argument parsing for collection script | Already in use |
| `timeout` (Ruby stdlib) | N/A | HTTP request timeouts | Already in use |

No new gems or external dependencies are needed. Everything required for the
new features is available in Ruby stdlib, which is the correct constraint for
a Puppet module that runs on PE-managed nodes.

**Confidence:** HIGH (verified against existing codebase imports)

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|---|---|---|---|
| Dashboard generation | Ruby hashes to JSON | ERB/EPP templates | JSON templating in ERB is brittle, unreadable, and hard to test |
| Dashboard generation | Ruby hashes to JSON | Grafonnet (jsonnet) | Adds build-time dependency; overkill for this use case |
| Dashboard generation | Ruby hashes to JSON | Grafana Terraform provider | Wrong tool; this is a Puppet module, not Terraform |
| Dashboard provisioning | Static JSON files | Grafana HTTP API | PROJECT.md explicitly scopes this out; files are portable |
| Config format | YAML | JSON | YAML already chosen and implemented; more human-friendly for users |
| Config format | YAML | TOML | Non-standard in Puppet ecosystem; YAML already chosen |
| Self-monitoring | Ruby Process module | `/proc` filesystem parsing | Process module is cross-platform; `/proc` is Linux-only |
| Metric validation | Regex in Ruby | External schema validator | No dependency needed; Prometheus naming rules are simple regexes |

## Dashboard Generation Architecture

The dashboard generator should be a Ruby class within the existing collection
script (or a separate file sourced by it). The recommended structure:

```ruby
class GrafanaDashboardGenerator
  def initialize(metric_definitions, config)
    @metrics = metric_definitions
    @config = config
  end

  def generate_all
    @metrics.map { |defn| generate_dashboard(defn) }
  end

  def generate_dashboard(defn)
    {
      "schemaVersion" => 41,
      "title" => "Puppet Custom: #{defn['name'].tr('_', ' ').capitalize}",
      "uid" => generate_uid(defn['name']),
      "tags" => ["puppet", "custom"],
      "editable" => true,
      "templating" => standard_variables,
      "panels" => panels_for_metric(defn),
      "time" => { "from" => "now-7d", "to" => "now" },
      "timezone" => "browser",
      "version" => 1,
      "weekStart" => "monday"
    }
  end

  private

  def generate_uid(name)
    # Deterministic UID from metric name (Grafana UIDs must be unique)
    require 'digest'
    "puppet_custom_#{Digest::SHA256.hexdigest(name)[0..7]}"
  end

  def standard_variables
    # Reuse the DS_PROMETHEUS, interval, environment pattern
    # from existing dashboards
  end

  def panels_for_metric(defn)
    # Select panel types based on metric characteristics
  end
end
```

**Where dashboards are written:** To a configurable directory
(default: `/opt/puppetlabs/puppet_data_connector_enhancer/dashboards/`).
Users copy or symlink these into Grafana's provisioning directory. This follows
the PROJECT.md constraint of "generate JSON files only, user imports manually".

**Confidence:** MEDIUM (architecture recommendation based on codebase patterns;
the specific panel generation logic will need refinement during implementation)

## Metric Name Validation

Custom metric names from user YAML must be validated. Add validation in the
`collect_custom_metrics` method:

```ruby
PROMETHEUS_METRIC_NAME = /\A[a-zA-Z_:][a-zA-Z0-9_:]*\z/
PROMETHEUS_LABEL_NAME = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

def valid_metric_name?(name)
  name.match?(PROMETHEUS_METRIC_NAME) && !name.start_with?('__')
end

def valid_label_name?(name)
  name.match?(PROMETHEUS_LABEL_NAME) && !name.start_with?('__')
end
```

Names starting with `__` are reserved by Prometheus. Names starting with
`puppet_` should be enforced as a prefix convention for this module's metrics,
but the validator should warn rather than reject non-prefixed names.

**Confidence:** HIGH (Prometheus naming specification is stable)

## Installation

No new installation steps required. The module's existing deployment via Puppet
handles everything:

```puppet
# Existing module usage (unchanged)
class { 'puppet_data_connector_enhancer':
  puppet_server => $facts['puppet_server'],
  custom_metrics => [
    {
      'name'     => 'puppet_custom_nodes_by_role',
      'type'     => 'gauge',
      'help'     => 'Number of nodes per role',
      'endpoint' => 'pql',
      'pql_query' => 'nodes[certname,trusted.extensions.pp_role] {}',
      'labels'   => { 'role' => 'trusted.extensions.pp_role' },
    },
  ],
}
```

## Version Compatibility Matrix

| Component | Minimum | Maximum | Notes |
|---|---|---|---|
| Puppet Enterprise | 7.24 | 9.0.0 (exclusive) | Per metadata.json |
| Grafana | 10.0 | 11.x | schemaVersion 41 targets Grafana 11; backwards compatible to 10 |
| Prometheus | 2.0 | 3.x | Text exposition format 0.0.4 is universally supported |
| node_exporter | 1.0 | 1.8+ | Textfile collector has been stable since 1.0 |
| Ruby | 2.7 | 3.2 | PE-embedded Ruby range |

**Confidence:** HIGH for Puppet/Prometheus/node_exporter (stable, well-known
compatibility). MEDIUM for Grafana schema version (41 is current but Grafana
evolves the schema; dashboards remain importable across versions).

## Sources

- Existing codebase analysis: 9 dashboard JSON files in `files/`, main
  collection script template, custom queries YAML template, manifests
- Prometheus exposition format specification (training data, stable since 2014)
- Prometheus exporter authoring guidelines (training data, well-established
  conventions)
- Grafana dashboard JSON model (derived from existing dashboard analysis,
  schemaVersion 41)

**Note:** Web search and documentation fetch tools were unavailable during this
research. All recommendations are based on codebase analysis and training data.
The Prometheus text format and Grafana dashboard JSON model are both mature,
stable specifications where training data is reliable. Confidence levels are
adjusted accordingly; no LOW-confidence claims are presented as authoritative.

---

*Stack analysis: 2026-04-05*
