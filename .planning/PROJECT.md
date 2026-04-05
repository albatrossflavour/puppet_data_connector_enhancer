# Puppet Data Connector Enhancer - Self-Service Graphs

## What This Is

An enhancement to the Puppet Data Connector Enhancer module that adds self-service custom metrics and auto-generated Grafana dashboards. Users discover useful PQL queries through the Puppet Infra Assistant chatbot, paste them into a YAML config, and the module handles both Prometheus metric collection and Grafana dashboard generation automatically.

## Core Value

Users can turn any PQL query into an ongoing Prometheus metric with a matching Grafana dashboard, without writing Ruby or understanding the metrics pipeline.

## Requirements

### Validated

- ✓ Core metrics collection via systemd timer — existing
- ✓ Prometheus node exporter textfile collector integration — existing
- ✓ SCM CIS score collection — existing
- ✓ HTTP retry logic with exponential backoff — existing
- ✓ Per-metric error isolation — existing
- ✓ Sample Grafana dashboards (JSON) — existing
- ✓ Orchestrator job and plan metrics from Orchestrator API (port 8143) — Validated in Phase 1
- ✓ Node group classification metrics from Classifier API (port 4433) — Validated in Phase 1
- ✓ Class usage metrics (count of nodes per class) — Validated in Phase 1
- ✓ Test coverage for orchestrator and classification metrics — Validated in Phase 1
- ✓ Merge feature/orchestrator-metrics branch work — Validated in Phase 1

### Active

- [ ] Custom metrics YAML config system (4 endpoint types: fact, pql, resource, inventory)
- [ ] Dot-path JSON extraction for nested values as Prometheus labels
- [ ] HELP/TYPE header generation for custom metrics
- [ ] Auto-generated Grafana dashboard JSON for each custom metric definition
- [ ] Prometheus alert rules examples for all metrics
- [ ] Updated README with custom queries usage guide and YAML format reference
- [ ] Updated REFERENCE.md with all new parameters
- [ ] Test coverage for error scenarios (bad YAML, missing config, API failures)
- [ ] Self-monitoring metrics: collection script resource usage (CPU, memory, wall time)
- [ ] Self-monitoring metrics: API call counts and durations per endpoint (PuppetDB, Orchestrator, Classifier)
- [ ] Self-monitoring metrics: collection health (success/failure rates, timeouts, error counts per run)
- [ ] Self-monitoring metrics: total metrics collected per run

### Out of Scope

- Chatbot UI modifications — cannot alter the Puppet Infra Assistant interface
- Direct Grafana API provisioning — generate JSON files only, user imports manually
- Real-time metric streaming — stays on systemd timer collection model
- Puppet Forge release — merge to main only for this milestone

## Context

- This is a brownfield Puppet module (Ruby/Puppet DSL) published on the Puppet Forge
- The custom metrics YAML system is partially implemented on the `self_service_graphs` branch
- Orchestrator/classification metrics merged from `feature/orchestrator-metrics` in Phase 1 (1444 tests passing)
- The module runs on the Puppet server, authenticating to PuppetDB, Orchestrator, and Classifier APIs via SSL client certificates
- Grafana dashboards are currently shipped as static JSON files in the module
- Users discover useful PQL queries via the Puppet Infra Assistant chatbot, which shows the PQL that produced results

## Constraints

- **Tech stack**: Ruby (Puppet's embedded Ruby), Puppet DSL, ERB/EPP templates
- **API auth**: SSL client certificates from `/etc/puppetlabs/puppet/ssl/`
- **Compatibility**: Must work with Puppet Enterprise Advanced (PuppetDB v4 API)
- **No UI hooks**: Cannot modify the chatbot UI, so the workflow is copy/paste of PQL queries into YAML config

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| YAML config for custom metrics | Simple, human-readable, safe (YAML.safe_load) | ✓ Good |
| Generate Grafana JSON files (not API push) | Environment-agnostic, user controls provisioning | — Pending |
| Merge orchestrator-metrics into this branch | Consolidate all new features for single release | — Pending |
| Dashboard per custom metric | Each metric definition produces its own dashboard JSON | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):

1. Requirements invalidated? Move to Out of Scope with reason
2. Requirements validated? Move to Validated with phase reference
3. New requirements emerged? Add to Active
4. Decisions to log? Add to Key Decisions
5. "What This Is" still accurate? Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):

1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

*Last updated: 2026-04-05 after initialisation*
