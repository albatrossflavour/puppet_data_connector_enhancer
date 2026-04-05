# Requirements: Puppet Data Connector Enhancer - Self-Service Graphs

**Defined:** 2026-04-05
**Core Value:** Users can turn any PQL query into an ongoing Prometheus metric with a matching Grafana dashboard, without writing Ruby or understanding the metrics pipeline.

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Orchestrator and Classification Metrics

- [ ] **ORCH-01**: Module collects orchestrator job metrics (duration, status, node count) from PE Orchestrator API
- [ ] **ORCH-02**: Module collects orchestrator plan metrics (duration, status) from PE Orchestrator API
- [ ] **ORCH-03**: Module collects node group classification metrics with hierarchy from Classifier API
- [ ] **ORCH-04**: Module collects class usage metrics (count of nodes using each class)
- [ ] **ORCH-05**: Orchestrator and classification collection is disabled by default and enabled via Puppet parameters

### Custom Metrics

- [ ] **CUST-01**: User can define custom metrics via YAML config with four endpoint types (fact, pql, resource, inventory)
- [ ] **CUST-02**: YAML config is validated at schema level (missing required fields, invalid endpoint types, not just syntax)
- [ ] **CUST-03**: Custom metric names are checked against built-in metric names and a warning is logged on collision
- [ ] **CUST-04**: Each custom metric has a configurable row limit to prevent cardinality explosion
- [ ] **CUST-05**: EPP template correctly escapes PQL queries containing internal quotes
- [ ] **CUST-06**: Custom metrics support dot-path JSON extraction for nested values as Prometheus labels

### Grafana Dashboards

- [ ] **GRAF-01**: Module generates a combined Grafana dashboard JSON with one panel per custom metric definition
- [ ] **GRAF-02**: Generated dashboards use Grafana template variables for datasource selection (not hardcoded UIDs)
- [ ] **GRAF-03**: Panel type is automatically inferred from metric type (gauge/counter) and label cardinality
- [ ] **GRAF-04**: Module generates an overview dashboard showing all custom metrics at a glance

### Self-Monitoring

- [ ] **SMON-01**: Module emits metrics for collection script wall time, CPU usage, and memory usage
- [ ] **SMON-02**: Module emits metrics for API call count and duration per endpoint (PuppetDB, Orchestrator, Classifier)
- [ ] **SMON-03**: Module emits metrics for success/failure/timeout count per collector
- [ ] **SMON-04**: Module emits total metrics collected per run

### Documentation

- [ ] **DOCS-01**: README updated with custom queries usage guide and YAML format reference
- [ ] **DOCS-02**: Example YAML files provided for common custom metric use cases
- [ ] **DOCS-03**: REFERENCE.md regenerated with all new parameters documented
- [ ] **DOCS-04**: Prometheus alert rules examples updated for new metrics

### Testing

- [ ] **TEST-01**: Tests cover custom metrics error scenarios (bad YAML, missing config, invalid schema)
- [ ] **TEST-02**: Tests cover orchestrator and classification metric collection
- [ ] **TEST-03**: Tests cover Grafana dashboard JSON generation (valid JSON, correct panel types)
- [ ] **TEST-04**: Tests cover self-monitoring metric emission

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Custom Metrics

- **CUST-V2-01**: YAML validation CLI mode (dry-run queries without collecting)
- **CUST-V2-02**: Per-query timeout configuration in YAML

### Grafana Dashboards

- **GRAF-V2-01**: Direct Grafana API provisioning (push dashboards via HTTP API)
- **GRAF-V2-02**: Per-metric individual dashboard files (in addition to combined)

### Integration

- **INTG-V2-01**: Chatbot export action that outputs YAML snippet directly

## Out of Scope

| Feature | Reason |
|---------|--------|
| Chatbot UI modifications | Cannot alter the Puppet Infra Assistant interface |
| Direct Grafana API provisioning | Generate JSON files only; environment-agnostic approach |
| Real-time metric streaming | Stays on systemd timer collection model |
| Puppet Forge release | Merge to main only for this milestone |
| Computation engine in custom metrics | Metrics are raw values; Prometheus handles aggregation |
| Interactive config UI | Copy/paste workflow is sufficient for v1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORCH-01 | Pending | Pending |
| ORCH-02 | Pending | Pending |
| ORCH-03 | Pending | Pending |
| ORCH-04 | Pending | Pending |
| ORCH-05 | Pending | Pending |
| CUST-01 | Pending | Pending |
| CUST-02 | Pending | Pending |
| CUST-03 | Pending | Pending |
| CUST-04 | Pending | Pending |
| CUST-05 | Pending | Pending |
| CUST-06 | Pending | Pending |
| GRAF-01 | Pending | Pending |
| GRAF-02 | Pending | Pending |
| GRAF-03 | Pending | Pending |
| GRAF-04 | Pending | Pending |
| SMON-01 | Pending | Pending |
| SMON-02 | Pending | Pending |
| SMON-03 | Pending | Pending |
| SMON-04 | Pending | Pending |
| DOCS-01 | Pending | Pending |
| DOCS-02 | Pending | Pending |
| DOCS-03 | Pending | Pending |
| DOCS-04 | Pending | Pending |
| TEST-01 | Pending | Pending |
| TEST-02 | Pending | Pending |
| TEST-03 | Pending | Pending |
| TEST-04 | Pending | Pending |

**Coverage:**

- v1 requirements: 27 total
- Mapped to phases: 0
- Unmapped: 27

---

*Requirements defined: 2026-04-05*
*Last updated: 2026-04-05 after initial definition*
