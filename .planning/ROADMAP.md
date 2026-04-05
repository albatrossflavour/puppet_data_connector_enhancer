# Roadmap: Puppet Data Connector Enhancer - Self-Service Graphs

## Overview

This milestone turns the Puppet Data Connector Enhancer from a fixed-metric exporter into a self-service observability tool. The work moves through four phases: merge the already-implemented orchestrator metrics, build the custom metrics YAML engine (the critical path), layer on self-monitoring and auto-generated Grafana dashboards, then tie it all together with documentation and alert rule examples. The YAML schema is the linchpin, everything downstream depends on it being stable.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Orchestrator and Classification Metrics** - Merge the feature branch, test, and ship PE infrastructure visibility
- [ ] **Phase 2: Custom Metrics Engine** - Build the YAML-to-Prometheus pipeline with validation, safety guards, and dot-path extraction
- [ ] **Phase 3: Dashboards and Self-Monitoring** - Auto-generate Grafana dashboards from metric definitions and instrument the collector itself
- [ ] **Phase 4: Documentation and Alert Rules** - Usage guides, YAML reference, example alerts, and parameter documentation

## Phase Details

### Phase 1: Orchestrator and Classification Metrics

**Goal**: Users get visibility into PE orchestrator jobs, plans, and node classification without any new development, just a clean merge and validation of existing work
**Depends on**: Nothing (first phase)
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05, TEST-02
**Success Criteria** (what must be TRUE):

1. Module collects orchestrator job metrics (duration, status, node count) when enabled via Puppet parameter
2. Module collects orchestrator plan metrics (duration, status) when enabled via Puppet parameter
3. Module collects node group classification and class usage metrics from the Classifier API
4. Orchestrator and classification collection is off by default and toggleable via class parameters
5. Tests validate orchestrator and classification metric collection, including error scenarios

**Plans**: 2 plans

Plans:

- [x] 01-01-PLAN.md -- Apply orchestrator and classification code from feature branch to all four target files
- [x] 01-02-PLAN.md -- Apply test contexts and validate full rspec-puppet suite passes

### Phase 2: Custom Metrics Engine

**Goal**: Users can paste a PQL query into a YAML file and get a working Prometheus metric, with the module handling validation, safety, and formatting automatically
**Depends on**: Phase 1
**Requirements**: CUST-01, CUST-02, CUST-03, CUST-04, CUST-05, CUST-06, TEST-01
**Success Criteria** (what must be TRUE):

1. User can define a custom metric in YAML using any of the four endpoint types (fact, pql, resource, inventory) and see it appear in Prometheus exposition output
2. Module rejects invalid YAML configs with clear, actionable error messages (missing fields, invalid types, bad schema)
3. Module warns on metric name collisions with built-in metrics and enforces the `puppet_custom_` prefix
4. Each custom metric respects a configurable row limit, preventing cardinality explosion from broad queries
5. Dot-path JSON extraction works for nested values, producing correct Prometheus labels

**Plans**: TBD

Plans:

- [ ] 02-01: TBD

### Phase 3: Dashboards and Self-Monitoring

**Goal**: Every custom metric definition automatically produces a Grafana dashboard panel, and the collector reports its own health and resource usage
**Depends on**: Phase 2
**Requirements**: GRAF-01, GRAF-02, GRAF-03, GRAF-04, SMON-01, SMON-02, SMON-03, SMON-04, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):

1. Module generates valid Grafana dashboard JSON with one panel per custom metric definition, using template variables for datasource selection
2. Panel type is automatically inferred from metric type and label cardinality (no manual panel configuration needed)
3. An overview dashboard exists showing all custom metrics at a glance
4. Collection script emits self-monitoring metrics: wall time, CPU, memory, API call counts/durations, success/failure rates, and total metrics per run
5. Tests validate both dashboard JSON generation (structure, panel types) and self-monitoring metric emission

**Plans**: TBD
**UI hint**: yes

Plans:

- [ ] 03-01: TBD

### Phase 4: Documentation and Alert Rules

**Goal**: Users have everything they need to adopt the module: usage guides with copy-paste examples, complete parameter reference, and ready-to-use alert rules
**Depends on**: Phase 3
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):

1. README contains a custom queries usage guide with YAML format reference and copy-paste examples for each endpoint type
2. Example YAML files exist for common custom metric use cases (node counts, patch compliance, certificate expiry, etc.)
3. REFERENCE.md includes all new parameters (orchestrator, classification, custom metrics, dashboard generation)
4. Example Prometheus alert rules cover the key scenarios: collection failures, node count changes, orchestrator failures, and custom metric thresholds

**Plans**: TBD

Plans:

- [ ] 04-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Orchestrator and Classification Metrics | 0/2 | Planning complete | - |
| 2. Custom Metrics Engine | 0/0 | Not started | - |
| 3. Dashboards and Self-Monitoring | 0/0 | Not started | - |
| 4. Documentation and Alert Rules | 0/0 | Not started | - |
