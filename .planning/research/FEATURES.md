# Feature Landscape

**Domain:** Puppet infrastructure metrics exporter with self-service observability
**Researched:** 2026-04-05
**Confidence:** MEDIUM (domain expertise, codebase analysis; web search unavailable)

## Table Stakes

Features users expect from an infrastructure metrics exporter with self-service
capabilities. Missing any of these and the system feels half-baked.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| HELP/TYPE headers for all metrics | Prometheus best practice; tools like `promtool check metrics` fail without them; Grafana metric explorer uses HELP text for discovery | Low | Custom metrics already have this via `collect_custom_metric_headers`. Verify built-in metrics also emit headers consistently. |
| Per-metric error isolation | One failing query must not kill the entire collection run. Users expect partial results over no results. | Low | Already implemented via `collect_with_error_handling`. Validated. |
| YAML config validation with clear errors | Users will get YAML wrong. The error message is the product at that point. Bad YAML errors that reference line numbers and field names are table stakes for any config-driven system. | Medium | Current `YAML.safe_load` catches syntax errors. Need schema-level validation: missing required fields, invalid endpoint types, bad dot-paths. |
| Metric naming consistency | All metrics must follow `puppet_*` namespace convention with snake_case. Prometheus naming conventions are not optional; breaking them means PromQL queries become unpredictable. | Low | Enforce in validation. Reject or auto-prefix metric names that do not start with `puppet_`. |
| Duplicate metric detection | Two custom metrics emitting the same series (name + label set) corrupts the .prom file. Prometheus will reject it. | Low | Already implemented via `@seen_metrics` Set. Validated. |
| Atomic file writes | Partial writes to the .prom file mean Prometheus scrapes half-written data. Textfile collector is not atomic by default. | Low | Already implemented via temp file + rename pattern. Validated. |
| Retry logic with backoff | PE APIs go through maintenance windows, have brief outages during code deployments. Single-attempt collection is unacceptable. | Low | Already implemented with configurable retries and exponential backoff. Validated. |
| Documentation with examples | Every config field needs a working example. PQL queries are fiddly; users need copy-paste-modify examples for each endpoint type (fact, pql, resource, inventory). | Medium | README update is in scope. Include at least 2 examples per endpoint type covering common use cases. |
| Orchestrator job metrics | PE Orchestrator is a core component. Task and plan run counts, durations, and statuses are standard operational visibility for any PE shop. | Medium | Implemented on `feature/orchestrator-metrics` branch. Needs merge and integration testing. |
| Node classification metrics | Node groups and class assignments are fundamental to how PE organises infrastructure. Operators need to see group membership counts and class usage. | Medium | Implemented on `feature/orchestrator-metrics` branch. Needs merge. |

## Differentiators

Features that set this apart from "just another exporter." Not expected, but
genuinely valuable. These are the features that make someone choose this module
over writing their own collection script.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| PQL-to-metric pipeline (self-service custom metrics) | The killer feature. Users paste a PQL query from the chatbot into YAML and get a Prometheus metric. No Ruby, no exporter code, no deployment pipeline. The gap between "I found useful data" and "I can graph it" drops to minutes. | Medium | Core of this milestone. The four endpoint types (fact, pql, resource, inventory) with dot-path label extraction cover the vast majority of PQL query shapes. |
| Auto-generated Grafana dashboards per custom metric | Eliminates the second gap: users should not need to learn Grafana JSON modelling to get a usable dashboard for their new metric. Generate sensible defaults based on metric shape. | High | This is the hardest feature. Dashboard JSON generation needs to handle different metric shapes: simple gauges, multi-label tables, time series. See detailed analysis below. |
| Self-monitoring metrics | The exporter reports on its own health: collection duration, API call counts, error rates, resource usage. This is what separates production-grade tooling from scripts. Operators can alert on "the monitoring is broken" rather than discovering it days later. | Medium | Wall time is trivial. Per-API-call instrumentation needs wrapping around `fetch_json_from_puppetdb`. CPU/memory via `/proc/self/status` or `Process` module. |
| Dot-path JSON extraction for labels | PQL returns nested JSON (facts are deeply nested hashes). Being able to specify `value.operatingsystem.name` as a label path rather than writing custom extraction code is what makes the YAML config actually usable. | Low | Already implemented via `resolve_json_path`. Validated. |
| Example Prometheus alert rules | Users get metrics but then need to know what to alert on. Shipping example alert rules (`.rules.yml` files) for common scenarios saves hours of "what threshold should I use?" | Low | Straightforward. Ship as static files alongside dashboards. Cover: collection failures, node count changes, patch compliance drops, orchestrator failures. |
| Infrastructure config metric | A single metric that encodes the PE infrastructure topology (server names, ports, protocols) as labels. Useful for multi-PE-server environments and for Grafana variable templating. | Low | Already implemented as `collect_infrastructure_config`. Validated. |

## Anti-Features

Things to deliberately NOT build. Each of these is tempting and wrong.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Direct Grafana API provisioning | Couples the module to Grafana's API, requires API keys or service accounts, introduces auth management, and breaks in air-gapped environments. The module runs on the Puppet server, not on Grafana. Push-based provisioning is a different tool's job. | Generate JSON files. Users import manually or use Grafana's file-based provisioning (`/etc/grafana/provisioning/dashboards/`). Document the provisioning approach. |
| Real-time metric streaming | Systemd timer collection at 30-minute intervals is the right model for infrastructure metrics. These are not application metrics; node counts and patch statuses do not change every second. Streaming adds complexity (long-lived connections, reconnection logic, backpressure) for zero user value. | Keep the timer model. If users want higher frequency, make the timer interval configurable (it already is). |
| Custom metric aggregation/computation | Users will ask for computed metrics (ratios, averages, rates). Do not implement this in the exporter. That is what PromQL is for. Building a computation engine in Ruby duplicates Prometheus poorly. | Document PromQL patterns for common computations. Show recording rule examples for expensive queries. |
| Multi-format output (InfluxDB, Datadog, etc.) | The module is built around Prometheus text format consumed by PE's data connector. Supporting other formats fragments the codebase and testing surface for a tiny audience. | Prometheus text format only. If users need other formats, they can use Prometheus remote write or a separate adapter. |
| Interactive config UI/wizard | The target workflow is: chatbot shows PQL, user pastes into YAML, Puppet deploys. Adding a web UI for config management is a separate product. The YAML file managed by Puppet is the interface. | Invest in excellent YAML validation and error messages instead. Good errors are cheaper and more maintainable than a UI. |
| Metric cardinality controls/limits | Tempting to add cardinality limits ("max 1000 time series per custom metric"). In practice, PQL queries against PuppetDB naturally bound cardinality (you have N nodes, not millions). The risk of cardinality explosion is low and the complexity of enforcement is high. | Document cardinality awareness. Warn in README that `inventory` endpoint queries against large estates may produce high-cardinality metrics. Let users self-regulate. |

## Grafana Dashboard Generation: Detailed Analysis

This is the most complex differentiating feature. Worth breaking down
separately.

### What Dashboard Generators Typically Support

Grafana dashboard JSON is a well-documented but verbose format. The existing
hand-crafted dashboards in this module demonstrate the patterns:

- **Datasource variables**: `DS_PROMETHEUS` datasource selector (required for
  portability across Grafana instances)
- **Interval variables**: Auto-interval for time-range-aware queries
- **Query variables**: Dynamic label value dropdowns populated from metric labels
- **Panel types**: stat, gauge, bargauge, barchart, table, timeseries
- **Thresholds**: Colour-coded value ranges (green/amber/red)
- **Links**: Cross-dashboard navigation, PE Console deep links

### What Auto-Generation Should Handle

For each custom metric definition, generate a dashboard containing:

| Metric Shape | Detection | Dashboard Layout |
|--------------|-----------|------------------|
| Single value, no labels | `value_field` set, no `labels` | Single stat panel |
| Single value, few labels (less than 5 distinct) | Labels with low cardinality | Stat panel per label value, or gauge panel |
| Multi-value with labels | `labels` map present, multiple rows expected | Table panel + optional bar chart |
| Count-based (value_field is null) | `value_field: null` (counts rows) | Stat panel showing count |

### What Auto-Generation Should NOT Handle

- Time series panels (metrics are gauge snapshots at collection time, not
  continuous counters)
- Complex multi-panel layouts (users can edit the generated dashboard)
- Alert rule integration within dashboards (ship alert rules separately)

### Recommended Generation Approach

Generate minimal, correct dashboards rather than trying to be clever:

1. Standard boilerplate: annotations, datasource variable, links to PE Console
2. One "overview" stat panel showing the total/count
3. One table panel showing all label dimensions if labels exist
4. One bar chart or gauge if numeric values with labels

Use the existing hand-crafted dashboards as structural templates. The
`puppet_status.json` and `puppet_os_overview.json` cover all the panel
patterns needed.

## Feature Dependencies

```text
YAML Config System ──→ Custom Metrics Collection ──→ Dashboard Generation
                                                  ──→ Example Alert Rules

Orchestrator API Integration ──→ Orchestrator Metrics ──→ Dashboard Generation
Classifier API Integration   ──→ Classification Metrics ──→ Dashboard Generation

Custom Metrics Collection ──→ Self-Monitoring Metrics
Orchestrator Metrics      ──→ Self-Monitoring Metrics
Classification Metrics    ──→ Self-Monitoring Metrics
```

Key dependency chain: custom metrics YAML config is the foundation. Nothing
else works without it being solid. Dashboard generation is the capstone; it
depends on having well-structured metric definitions to determine panel layout.

Self-monitoring wraps around everything else; it instruments the collection
process itself, so it logically comes last.

## MVP Recommendation

Prioritise in this order:

1. **YAML config validation** (table stakes) - Users will hit this first. Bad
   error messages here poison the entire self-service experience.
2. **Merge orchestrator/classification metrics** (table stakes) - Already
   implemented. Merge, test, validate. Low marginal effort, high value.
3. **Self-monitoring metrics** (differentiator) - Instrument the collection
   script. This is medium complexity but high operational value.
4. **Auto-generated Grafana dashboards** (differentiator) - The headline
   feature but also the most complex. Build after metrics collection is solid.
5. **Example alert rules** (differentiator) - Low effort, ship alongside
   dashboards.
6. **Documentation with examples** (table stakes) - Write last because it
   documents everything above.

Defer:

- **Cardinality warnings in validation**: Nice to have, not critical. Document
  the concern in README instead.
- **Dashboard customisation options in YAML**: Users can edit generated JSON
  directly. Do not over-engineer the YAML schema with dashboard appearance
  controls.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Table stakes features | HIGH | Based on codebase analysis and Prometheus/Grafana best practices (well-established standards) |
| Differentiators | HIGH | Based on project requirements and understanding of the Puppet operator workflow |
| Dashboard generation approach | MEDIUM | No web search available to verify current Grafana JSON schema version; relying on existing dashboard files as reference and training data knowledge of Grafana 10.x/11.x |
| Anti-features | HIGH | Based on architectural constraints documented in PROJECT.md and operational experience patterns |

## Sources

- Codebase analysis of existing metrics script (`templates/puppet_data_connector_enhancer.epp`)
- Existing Grafana dashboard JSON files (`files/*.json`)
- Custom queries YAML template (`templates/custom_queries.yaml.epp`)
- `feature/orchestrator-metrics` branch commit history
- PROJECT.md and INTEGRATIONS.md project documentation
- Prometheus exposition format conventions (training data, HIGH confidence -
  well-established standard)
- Grafana dashboard JSON model (training data, MEDIUM confidence - format is
  stable but exact field names may have shifted in recent versions)
