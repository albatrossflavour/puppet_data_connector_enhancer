---
phase: 01-orchestrator-and-classification-metrics
verified: 2026-04-05T09:00:00Z
status: human_needed
score: 5/5 must-haves verified
human_verification:
  - test: "Enable orchestrator metrics (enable_orchestrator_metrics => true) in a PE environment and trigger the systemd timer. Check that puppet_orchestrator_job_info, puppet_orchestrator_job_duration_seconds, puppet_orchestrator_job_node_count, puppet_orchestrator_job_status_total, puppet_orchestrator_plan_info, and puppet_orchestrator_plan_status_total appear in the .prom output file."
    expected: "All six orchestrator metric types present in /var/opt/puppetlabs/pe-puppet/pe_metrics/metrics.prom (or configured dropzone) with real job/plan data from the PE Orchestrator API"
    why_human: "SSL client cert auth against the live Orchestrator API on port 8143 cannot be verified from source code alone. The fetch_json_from_orchestrator method exists and uses VERIFY_PEER with PE's own PKI certs, but live execution against a real PE Orchestrator is needed to confirm the connection succeeds and data flows into Prometheus exposition."
  - test: "Enable classification metrics (enable_classification_metrics => true) and trigger the collection run. Check that puppet_node_group_info, puppet_node_group_edge, puppet_class_usage_total, and puppet_classes_per_node appear with correct values."
    expected: "Node group hierarchy reflected in puppet_node_group_edge values. puppet_class_usage_total shows realistic class usage counts from PuppetDB. puppet_classes_per_node is populated per node."
    why_human: "Classifier API on port 4433 requires SSL client cert auth and a live PE environment. The DFS tree traversal in collect_node_groups produces puppet_node_group_edge metrics whose correctness depends on the actual node group hierarchy."
---

# Phase 1: Orchestrator and Classification Metrics Verification Report

**Phase Goal:** Users get visibility into PE orchestrator jobs, plans, and node classification without any new development, just a clean merge and validation of existing work
**Verified:** 2026-04-05T09:00:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Orchestrator job and plan collection methods exist in the generated script | VERIFIED | `def collect_orchestrator_jobs` at EPP line 715, `def collect_orchestrator_plans` at line 784. Both present with full implementation bodies. |
| 2 | Classification collection methods (node groups and class usage) exist in the generated script | VERIFIED | `def collect_node_groups` at EPP line 842 with DFS tree traversal, `def collect_class_usage` at line 929. Both present with full implementation bodies. |
| 3 | Both feature flags default to false and gate collector invocation | VERIFIED | `Boolean $enable_orchestrator_metrics = false` and `Boolean $enable_classification_metrics = false` in manifest (lines 180, 182). EPP generate_metrics wraps collector calls in `if @config[:enable_orchestrator_metrics]` (line 69) and `if @config[:enable_classification_metrics]` (line 74). Hiera defaults confirmed in data/common.yaml. |
| 4 | SSL client certificate auth is used for Orchestrator and Classifier API calls | VERIFIED | `fetch_json_from_orchestrator` uses `http.verify_mode = OpenSSL::SSL::VERIFY_PEER` (EPP line 370), `http.cert = OpenSSL::X509::Certificate.new(File.read(@config[:ssl_cert_file]))` (line 371), `http.key = OpenSSL::PKey::RSA.new(File.read(@config[:ssl_key_file]))` (line 372). Config keys `ssl_cert_file`, `ssl_key_file`, `ssl_ca_file` populated from PE PKI paths with env var overrides (EPP lines 113-115). |
| 5 | All 13 metric types are emitted with correct names and labels | VERIFIED | Confirmed 13 `add_metric` calls for orchestrator/classification metrics. Orchestrator jobs (5): job_info, job_duration_seconds, job_start_timestamp, job_node_count, job_status_total. Orchestrator plans (4): plan_info, plan_duration_seconds, plan_start_timestamp, plan_status_total. Classification (4): node_group_info, node_group_edge, class_usage_total, classes_per_node. All 13 also registered in header_metrics via conditional merge! blocks. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `manifests/init.pp` | Three new parameters with docs, examples, typed declarations, EPP hash keys | VERIFIED | `@param` docs at lines 85-95, examples at 119-125, declarations `Boolean $enable_orchestrator_metrics = false`, `Integer[1, 200] $orchestrator_jobs_limit = 50`, `Boolean $enable_classification_metrics = false` at lines 180-182, EPP hash keys at lines 266-268. All present and wired. |
| `templates/puppet_data_connector_enhancer.epp` | Four collector methods, SSL HTTP client, feature flag conditionals, restructured header_metrics | VERIFIED | All four collector methods present (lines 715, 784, 842, 929). `fetch_json_from_orchestrator` with VERIFY_PEER and client cert at lines 370-373. Feature flag conditionals in generate_metrics at lines 69-77. header_metrics restructured with 3x `merge!` calls (count: 3). EPP param block contains all three new Boolean/Integer parameters. |
| `data/common.yaml` | Default values for three new parameters | VERIFIED | `puppet_data_connector_enhancer::enable_orchestrator_metrics: false`, `puppet_data_connector_enhancer::orchestrator_jobs_limit: 50`, `puppet_data_connector_enhancer::enable_classification_metrics: false` all present. |
| `spec/classes/puppet_data_connector_enhancer_spec.rb` | Six test contexts for orchestrator and classification | VERIFIED | All six contexts present at lines 475-580, correctly positioned before `context 'resource ordering'` at line 583. Content matchers use `%r{...}` syntax per conventions. Boundary validation tests at lines 537, 547 use `compile.and_raise_error`. |
| `spec/stubs/puppet_data_connector/manifests/init.pp` | Stub class for premium PE module dependency | VERIFIED | File exists (310B). Referenced via `.fixtures.yml` symlinks entry at line 11. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `manifests/init.pp` | `templates/puppet_data_connector_enhancer.epp` | `epp()` hash passes all three new parameters | WIRED | Lines 266-268 in init.pp pass `enable_orchestrator_metrics`, `orchestrator_jobs_limit`, `enable_classification_metrics` to EPP hash. EPP param block declares all three at lines 12-14. |
| `data/common.yaml` | `manifests/init.pp` | Hiera parameter defaults | WIRED | All three parameter defaults in common.yaml match the inline defaults in init.pp (both `false`/`50`). Hiera lookup will provide these at catalog compilation. |
| `spec/classes/puppet_data_connector_enhancer_spec.rb` | `manifests/init.pp` | rspec-puppet compiles class with test parameters | WIRED | All six test contexts use `is_expected.to compile.with_all_deps` or `compile.and_raise_error`. Parameters passed via `super().merge(...)` pattern. |
| `spec/classes/puppet_data_connector_enhancer_spec.rb` | `templates/puppet_data_connector_enhancer.epp` | `with_content` matchers verify template output | WIRED | Content matchers verify `collect_orchestrator_jobs`, `collect_orchestrator_plans`, `collect_node_groups`, `collect_class_usage`, `enable_orchestrator_metrics:.*true/false`, `orchestrator_jobs_limit:.*100/25`, `def fetch_json_from_orchestrator`, `enable_classification_metrics:.*true/false`. |

### Data-Flow Trace (Level 4)

The four collector methods render dynamic data fetched from live APIs (Orchestrator on port 8143, Classifier on port 4433, PuppetDB). Code-level data flow is verified below. Live API correctness requires human testing (see Human Verification Required).

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `collect_orchestrator_jobs` | `jobs` array | `fetch_json_from_orchestrator("#{orchestrator_base_url}/orchestrator/v1/jobs?limit=#{limit}")` | Yes -- paginated API fetch with SSL client cert auth and retry/backoff | FLOWING (code path verified; live API needs human test) |
| `collect_orchestrator_plans` | `plans` array | `fetch_json_from_orchestrator("#{orchestrator_base_url}/orchestrator/v1/plan_jobs?limit=#{limit}")` | Yes -- same SSL HTTP client, different endpoint | FLOWING (code path verified; live API needs human test) |
| `collect_node_groups` | `groups` array | `fetch_json_from_orchestrator("#{classifier_base_url}/classifier-api/v1/groups")` | Yes -- Classifier API with SSL client cert auth | FLOWING (code path verified; live API needs human test) |
| `collect_class_usage` | PuppetDB query result | `fetch_json("/pdb/query/v4")` with Class resource query body | Yes -- PuppetDB query, existing HTTP client pattern | FLOWING (code path verified) |

### Behavioral Spot-Checks

Static code verification only. No live PE environment available to execute collection scripts.

| Behaviour | Command | Result | Status |
|-----------|---------|--------|--------|
| rspec-puppet suite passes | `bundle exec rake spec` | 1444 examples, 0 failures (per 01-02-SUMMARY.md, commit 65b0781) | PASS (documented; commit exists and is verified) |
| No conflict markers in modified files | `grep -rn "<<<<<<" manifests/ templates/ data/ spec/` | No output | PASS |
| `collect_custom_metrics` not broken | `grep -n "collect_custom_metrics"` in EPP template | Present at line 79 in generate_metrics, defined at line 1011 | PASS |
| Manifest EPP param count matches hash key count | Count EPP params vs epp() hash keys | 3 new params declared in EPP block; 3 new keys in EPP hash in init.pp | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ORCH-01 | 01-01-PLAN.md | Module collects orchestrator job metrics (duration, status, node count) from PE Orchestrator API | SATISFIED | `collect_orchestrator_jobs` emits puppet_orchestrator_job_info, _duration_seconds, _start_timestamp, _node_count, _job_status_total (5 metric types) via SSL-authenticated API call |
| ORCH-02 | 01-01-PLAN.md | Module collects orchestrator plan metrics (duration, status) from PE Orchestrator API | SATISFIED | `collect_orchestrator_plans` emits puppet_orchestrator_plan_info, _duration_seconds, _start_timestamp, _plan_status_total (4 metric types) |
| ORCH-03 | 01-01-PLAN.md | Module collects node group classification metrics with hierarchy from Classifier API | SATISFIED | `collect_node_groups` performs DFS tree traversal, emits puppet_node_group_info and puppet_node_group_edge with parent relationship labels |
| ORCH-04 | 01-01-PLAN.md | Module collects class usage metrics (count of nodes using each class) | SATISFIED | `collect_class_usage` queries PuppetDB for Class resources, emits puppet_class_usage_total and puppet_classes_per_node |
| ORCH-05 | 01-01-PLAN.md | Orchestrator and classification collection is disabled by default and enabled via Puppet parameters | SATISFIED | Both parameters default to `false` in manifest and Hiera. generate_metrics wraps each feature's collectors in conditional blocks gated on `@config[:enable_orchestrator_metrics]` and `@config[:enable_classification_metrics]` |
| TEST-02 | 01-02-PLAN.md | Tests cover orchestrator and classification metric collection | SATISFIED | Six rspec-puppet contexts present; compilation tests, content matcher tests for method names and config values, boundary validation tests for `Integer[1, 200]` constraint. Test suite passed 1444 examples with 0 failures. |

**No orphaned requirements.** REQUIREMENTS.md maps ORCH-01 through ORCH-05 and TEST-02 to Phase 1. All six are claimed by plans 01-01 and 01-02 and verified above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `templates/puppet_data_connector_enhancer.epp` | 208 | `http.verify_mode = OpenSSL::SSL::VERIFY_NONE` | Info | This is in the existing `fetch_json` method used for PuppetDB (port 8080, no SSL). The new `fetch_json_from_orchestrator` correctly uses `VERIFY_PEER` at line 370. Two separate HTTP clients, each appropriate for its endpoint. Not a regression from this phase. |

No blockers or warnings found. The `VERIFY_NONE` at line 208 is pre-existing, scoped to the unencrypted PuppetDB connection, and unrelated to this phase's work.

### Human Verification Required

#### 1. Live Orchestrator Metrics Collection

**Test:** On a PE environment, apply the module with `enable_orchestrator_metrics => true` and `orchestrator_jobs_limit => 50`. Trigger the systemd timer (or run the script directly as the pe-puppet user). Inspect the .prom output file.
**Expected:** The output file contains entries for `puppet_orchestrator_job_info`, `puppet_orchestrator_job_duration_seconds`, `puppet_orchestrator_job_start_timestamp`, `puppet_orchestrator_job_node_count`, `puppet_orchestrator_job_status_total`, `puppet_orchestrator_plan_info`, `puppet_orchestrator_plan_duration_seconds`, `puppet_orchestrator_plan_start_timestamp`, and `puppet_orchestrator_plan_status_total` with real values from recent orchestrator runs.
**Why human:** SSL client cert mutual auth against the PE Orchestrator API on port 8143 cannot be exercised from static code inspection. The code path is wired correctly, but connection success and data format correctness (PE returns the expected JSON shape) requires a live PE environment.

#### 2. Live Classification Metrics Collection

**Test:** Apply the module with `enable_classification_metrics => true`. Trigger collection and inspect the .prom output.
**Expected:** `puppet_node_group_info` contains entries for all node groups. `puppet_node_group_edge` reflects the parent-child hierarchy. `puppet_class_usage_total` shows realistic counts. `puppet_classes_per_node` is populated per managed node.
**Why human:** Classifier API on port 4433 requires SSL client cert auth and a live PE Classifier. The DFS tree traversal logic (producing puppet_node_group_edge) is only meaningful with a real node group hierarchy to traverse.

### Gaps Summary

No gaps. All five observable truths are verified at all four levels (exists, substantive, wired, data-flow code path). Two human verification items remain for live API correctness -- these are expected for any module that depends on PE infrastructure APIs and do not represent gaps in the implementation.

---

_Verified: 2026-04-05T09:00:00Z_
_Verifier: Claude (gsd-verifier)_
