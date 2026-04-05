# Architecture Patterns

**Domain:** Self-service metrics exporter with Grafana dashboard generation
**Researched:** 2026-04-05
**Confidence:** MEDIUM (based on codebase analysis and established patterns; web search unavailable for verification)

## Recommended Architecture

The new features slot into the existing architecture as three distinct subsystems that extend the current `PrometheusMetricsGenerator` class and the Puppet manifest layer. The key architectural insight is that all three subsystems (custom metrics, dashboard generation, self-monitoring) share the same data flow shape: config in, metrics/JSON out, written to disk for downstream consumption.

### High-Level Component Map

```text
Puppet Manifest Layer (init.pp)
  |
  +-- Custom Queries Config (YAML via EPP)      -- already exists
  |
  +-- Dashboard Generator (EPP-templated Ruby)   -- NEW
  |     |
  |     +-- reads custom_queries.yaml
  |     +-- writes Grafana JSON to files/generated/
  |
  +-- Metrics Collection Script (EPP-templated Ruby)
        |
        +-- Built-in collectors (existing)
        +-- Custom metric collector (partially exists)
        +-- Orchestrator/Classifier collectors    -- NEW (from feature branch)
        +-- Self-monitoring collector             -- NEW
        |
        +-- writes .prom to dropzone
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `init.pp` (Manifest) | Orchestrates all file deployment, validates params, manages systemd units | EPP templates, Hiera, systemd |
| Custom Queries YAML Config | Declares what custom metrics to collect, with enough metadata to generate dashboards | Read by metrics script at runtime, read by dashboard generator at compile time |
| `PrometheusMetricsGenerator` (Ruby) | Collects all metrics (built-in, custom, orchestrator, self-monitoring) and writes `.prom` output | PuppetDB API (:8080), Orchestrator API (:8143), Classifier API (:4433), Infra Assistant API (:8145) |
| Dashboard Generator (Ruby/EPP) | Reads custom metric definitions and produces Grafana dashboard JSON files | Reads `custom_queries.yaml` structure (or Puppet params directly), writes JSON files |
| Self-monitoring subsystem | Tracks exporter resource usage, API call metrics, and collection health | Internal to `PrometheusMetricsGenerator`, extends existing `add_exporter_health_metrics` |

## Data Flow

### Custom Metrics Flow (Existing, Needs Extension)

```text
1. User writes Hiera YAML:
   puppet_data_connector_enhancer::custom_queries:
     - name: puppet_custom_nginx_version
       endpoint: fact
       ...

2. Puppet compile time:
   init.pp --> EPP template --> custom_queries.yaml deployed to disk

3. Runtime (systemd timer):
   metrics script --> reads custom_queries.yaml
                  --> queries PuppetDB per definition
                  --> emits Prometheus metrics to .prom file
```

The custom metrics config is the single source of truth for both metric collection AND dashboard generation. This is the right design. One definition produces both the metric and its visualisation.

### Dashboard Generation Flow (New)

```text
1. Puppet compile time:
   init.pp reads $custom_queries parameter
     --> Dashboard generator iterates each metric definition
     --> For each definition, produces a Grafana dashboard JSON
     --> Writes JSON files to a managed directory (e.g., files/generated/ or $scm_dir/dashboards/)

2. User imports:
   User copies JSON files to Grafana (manual import or provisioning directory)
```

**Critical decision: compile-time vs runtime generation.** Generate dashboards at Puppet compile time, not at Ruby script runtime. The reasons are:

- Dashboard JSON does not change between collection runs; it only changes when the metric definition changes
- Compile-time generation means the dashboard files are managed Puppet resources with proper checksums and change detection
- No additional runtime dependencies or failure modes in the collection script
- Puppet's file resource handles atomic writes, ownership, and permissions

### Self-Monitoring Flow (New, Extends Existing)

```text
1. Runtime (within PrometheusMetricsGenerator):
   - @start_time captured at initialisation (already exists)
   - Each API call wrapped to capture: endpoint, duration, status code, error count
   - Each collection method wrapped to capture: wall time, row count
   - Process.times captured at end for CPU usage
   - GC.stat captured for memory pressure indicators

2. Output:
   - Self-monitoring metrics emitted alongside all other metrics in same .prom file
   - Uses existing add_metric/build_metric infrastructure
   - HELP/TYPE headers added to existing header_metrics hash
```

### Orchestrator and Classifier Metrics Flow (New, From Feature Branch)

```text
1. Runtime (systemd timer):
   metrics script --> queries Orchestrator API (:8143) for job/plan data
                  --> queries Classifier API (:4433) for node group data
                  --> queries PuppetDB for class usage (resources endpoint)
                  --> emits metrics to same .prom file

2. Authentication:
   Same SSL client certificate pattern as existing PuppetDB calls
   Certificates from /etc/puppetlabs/puppet/ssl/
```

## Patterns to Follow

### Pattern 1: Dashboard JSON Templating via Ruby Hash-to-JSON

**What:** Build Grafana dashboards by constructing Ruby hashes that mirror the Grafana JSON model, then serialise to JSON. Not string interpolation, not ERB templates for JSON.

**When:** Always, for generated dashboards. The existing static dashboards in `files/` are hand-crafted JSON, which is fine for static content. Generated dashboards need a programmatic approach.

**Why:** Grafana dashboard JSON is deeply nested with integer IDs, coordinate grids, and datasource references. String interpolation in JSON is fragile and produces invalid JSON on edge cases (unescaped quotes in metric names, etc.). Ruby hashes handle this naturally.

**Example:**

```ruby
def build_dashboard(metric_defn)
  {
    annotations: { list: [default_annotation] },
    editable: true,
    panels: build_panels_for_metric(metric_defn),
    tags: ['puppet', 'auto-generated'],
    templating: { list: [prometheus_datasource_variable] },
    time: { from: 'now-24h', to: 'now' },
    title: "Puppet: #{metric_defn['help'] || metric_defn['name']}",
    uid: generate_uid(metric_defn['name'])
  }
end

def build_panels_for_metric(defn)
  panels = []
  panels << build_stat_panel(defn, id: 1, grid_pos: { h: 4, w: 8, x: 0, y: 0 })
  panels << build_timeseries_panel(defn, id: 2, grid_pos: { h: 8, w: 24, x: 0, y: 4 })

  if defn['labels'] && defn['labels'].length > 1
    panels << build_table_panel(defn, id: 3, grid_pos: { h: 8, w: 24, x: 0, y: 12 })
  end

  panels
end
```

**Key structural elements every Grafana dashboard JSON needs:**

- `uid`: Unique, deterministic (derive from metric name so re-generation is idempotent)
- `templating.list`: At minimum a `${DS_PROMETHEUS}` datasource variable
- `panels[].datasource`: Reference to `${DS_PROMETHEUS}` datasource
- `panels[].targets[].expr`: The PromQL expression for the metric
- `panels[].gridPos`: Panel layout coordinates (`h`, `w`, `x`, `y`)
- `panels[].fieldConfig.defaults.thresholds`: Colour coding for stat panels

### Pattern 2: Self-Monitoring via Internal Instrumentation

**What:** Instrument the collection script itself rather than using an external monitoring agent. The exporter monitors itself.

**When:** Always. This is the standard Prometheus exporter pattern (every well-behaved exporter exposes `_scrape_duration_seconds`, `_scrape_success`, etc.).

**Why:** The existing script already does basic self-monitoring (scrape duration, success flag, timestamp). Extending this is far simpler than adding external monitoring. The metrics land in the same `.prom` file, so they are automatically scraped by the same pipeline.

**Implementation approach:**

```ruby
# Wrap API calls to capture per-endpoint stats
def instrumented_fetch(uri_str, params = {}, endpoint_label:)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    result = fetch_json_from_puppetdb(uri_str, params)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    record_api_call(endpoint_label, duration, 'success')
    result
  rescue => e
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    record_api_call(endpoint_label, duration, 'error')
    raise
  end
end

def record_api_call(endpoint, duration, status)
  @api_call_counts[endpoint] ||= { success: 0, error: 0 }
  @api_call_counts[endpoint][status.to_sym] += 1
  @api_call_durations[endpoint] ||= []
  @api_call_durations[endpoint] << duration
end
```

### Pattern 3: Metric Definition as Single Source of Truth

**What:** The custom metrics YAML definition drives both collection behaviour and dashboard generation. No separate dashboard config.

**When:** For all user-defined custom metrics.

**Why:** If users had to maintain two configurations (one for collection, one for dashboards), they would drift. The YAML already contains everything needed to generate a sensible dashboard: metric name, help text, type (gauge/counter), labels. The dashboard generator infers panel types from the metric type and label cardinality.

**Inference rules:**

| Metric Property | Dashboard Panel Type |
|----------------|---------------------|
| `type: gauge`, no labels | Single stat panel |
| `type: gauge`, with labels | Time series + table panel |
| `type: counter` | Time series with `rate()` applied |
| Labels include `node`/`certname` | Add node filter variable |
| Labels include `environment` | Add environment filter variable |
| `value_field: null` (presence metric) | Stat panel showing count |

## Anti-Patterns to Avoid

### Anti-Pattern 1: Runtime Dashboard Generation

**What:** Generating Grafana JSON inside the metrics collection script at runtime.

**Why bad:** The collection script runs every 30 minutes via systemd timer. Dashboard JSON only needs regenerating when the metric definitions change (which requires a Puppet run anyway). Mixing dashboard generation into the collection loop adds failure modes, increases runtime, and conflates two different concerns.

**Instead:** Generate dashboards at Puppet compile time. The `custom_queries` parameter is available in `init.pp`. Use a Puppet function or inline EPP to generate the JSON and deploy it as a managed `file` resource.

### Anti-Pattern 2: String Interpolation for JSON Generation

**What:** Using ERB/EPP string templates to generate Grafana dashboard JSON.

**Why bad:** Grafana JSON is 500+ lines of deeply nested structure with integer coordinates, arrays of objects, and escaped strings. EPP templates for this become unmaintainable, and a single misplaced comma produces invalid JSON that fails silently when imported into Grafana.

**Instead:** Use Ruby code that builds a hash structure and calls `JSON.pretty_generate`. This gives you programmatic control, proper escaping, and valid JSON by construction.

### Anti-Pattern 3: Monolithic Self-Monitoring

**What:** Adding dozens of self-monitoring metrics that individually track every internal operation.

**Why bad:** Self-monitoring should be lightweight. If the self-monitoring code is more complex than the actual collection code, something has gone wrong. Over-instrumentation also bloats the `.prom` file.

**Instead:** Focus on the metrics that actually help diagnose problems:

- Total scrape duration (already exists)
- Per-API-endpoint call count and total duration (not per-call)
- Collection success/failure per collector type (partially exists)
- Total metrics emitted (for trend detection)
- Process CPU and wall time (for resource usage alerting)

Skip: per-call latency histograms, memory allocation tracking, GC statistics. These are overkill for a batch script running every 30 minutes.

### Anti-Pattern 4: Dashboard Per Collection Run

**What:** Generating a new dashboard file every time the collection script runs, even if nothing changed.

**Why bad:** File churn, unnecessary I/O, confusing timestamps.

**Instead:** Dashboards are Puppet-managed file resources. They only change when the catalog changes (i.e., when metric definitions change). Puppet's built-in checksumming handles this correctly.

## Architecture Decision: Where Dashboard Generation Lives

There are two reasonable approaches. The right one depends on the Puppet module's constraints.

### Option A: Puppet Function (Recommended)

A custom Puppet function in `lib/puppet/functions/` that takes the `custom_queries` array and returns a hash of `{ filename => json_content }`. The manifest iterates this hash to create file resources.

**Advantages:**

- Runs at compile time on the Puppet master
- Full Ruby available (JSON generation is trivial)
- Output is a managed Puppet `file` resource with proper checksums
- Follows the existing `parse_csv` pattern in this module
- Dashboard files only update when definitions change

**Disadvantages:**

- Requires writing a new Puppet function (but the pattern already exists in this codebase)

### Option B: EPP Template Generating JSON

An EPP template that iterates `custom_queries` and produces JSON.

**Advantages:**

- Familiar pattern (already using EPP for YAML generation)
- No new Puppet function needed

**Disadvantages:**

- EPP is not well-suited to deeply nested JSON generation
- Easy to produce invalid JSON
- Hard to test in isolation
- Difficult to add conditional panel logic

**Recommendation:** Option A. The `parse_csv` function already establishes the pattern. A `generate_dashboards` function fits naturally alongside it. The JSON generation logic is testable with rspec-puppet.

## Scalability Considerations

| Concern | 5 custom metrics | 50 custom metrics | 200 custom metrics |
|---------|-----------------|-------------------|---------------------|
| Collection time | Negligible (5 API calls) | Noticeable (50 API calls, maybe 30s) | Problematic (200 API calls, could exceed timer interval) |
| `.prom` file size | Small (few KB) | Moderate (tens of KB) | Large (hundreds of KB if high-cardinality labels) |
| Dashboard files | 5 JSON files, manageable | 50 JSON files, still fine for Grafana | 200 dashboards would overwhelm Grafana's UI |
| Puppet compile time | Negligible | Noticeable | Could slow catalog compilation |

**Mitigations for scale:**

- Document recommended maximum (suggest 20-30 custom metrics)
- Add a validation warning in the Puppet function if count exceeds threshold
- Consider batching PuppetDB queries where possible (multiple fact lookups could be combined)
- For dashboard generation, consider a single "Custom Metrics Overview" dashboard that aggregates all custom metrics, rather than strictly one-per-metric

## Suggested Build Order

The dependency graph between new components determines the build order.

```text
1. Orchestrator/Classifier collectors
   (no dependencies on other new work, merges existing branch)
      |
2. Self-monitoring extension
   (extends existing health metrics, no dependencies on custom metrics)
      |
3. Custom metrics HELP/TYPE headers
   (partially exists, small extension to generate_output_content)
      |
4. Dashboard generator function
   (depends on custom metrics config being stable)
      |
5. Dashboard file deployment in init.pp
   (depends on generator function)
      |
6. Alert rules examples
   (depends on knowing all metric names, so comes last)
```

**Rationale for this order:**

- Steps 1 and 2 are independent of each other and could be done in parallel
- Step 3 is a small change that finalises the custom metrics contract (what HELP/TYPE text looks like)
- Steps 4 and 5 depend on the metric definition schema being stable, so they come after the collectors are settled
- Step 6 is documentation-like work that references everything else

**The critical path is:** custom metric schema stability --> dashboard generation. If the YAML schema changes after dashboards are built, the generator needs rework. So nail down the schema first.

## Sources

- Codebase analysis of existing Puppet module (HIGH confidence)
- Grafana dashboard JSON structure from existing `files/*.json` in the module (HIGH confidence)
- Prometheus exporter self-monitoring conventions from training data (MEDIUM confidence, standard pattern but not verified against current docs)
- Grafana dashboard JSON model knowledge from training data (MEDIUM confidence, Grafana's schema is stable but specific field requirements should be verified against current Grafana version in use)

---

*Architecture analysis: 2026-04-05*
