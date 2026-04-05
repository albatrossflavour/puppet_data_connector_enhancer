# Phase 1: Orchestrator and Classification Metrics - Research

**Researched:** 2026-04-05
**Domain:** Puppet module patch application, PE Orchestrator/Classifier API integration
**Confidence:** HIGH

## Summary

This phase is a merge-and-validate operation, not greenfield development. The existing
`feature/orchestrator-metrics` branch contains ~587 lines of tested, working code across
4 target files. The work is to extract that code as patches, apply them to the
`self_service_graphs` branch, resolve conflicts introduced by the custom queries code
already present on that branch, and validate that tests pass.

The critical finding from this research is that the `self_service_graphs` branch has
already diverged from `main` with custom queries functionality (commit `648aea4`). The
feature branch patches were authored against `main`, so they will not apply cleanly.
The manifest parameter list, EPP template parameter block, `load_configuration` method,
EPP hash passed from manifest, and header_metrics section all have additional content on
`self_service_graphs` that the patches do not expect. Manual conflict resolution is
required in all four target files.

**Primary recommendation:** Generate patches with
`git diff main...origin/feature/orchestrator-metrics`, apply with
`git apply --3way` for automatic conflict marking, then manually resolve the conflicts
in each file. The conflicts are predictable and well-scoped.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Extract the cumulative diff from feature/orchestrator-metrics as patches
  and apply manually to self_service_graphs. Do not use git merge or cherry-pick.
- **D-02:** Skip the CHANGELOG.md entries from the feature branch. Fresh changelog
  entries will be written at release time to reflect the final state.
- **D-03:** Only bring across the orchestrator/classification changes
  (manifests/init.pp, templates/puppet_data_connector_enhancer.epp,
  data/common.yaml, spec/classes/puppet_data_connector_enhancer_spec.rb). Skip
  version bumps and README fixes from the feature branch.
- **D-04:** Use SSL client certificates for Orchestrator API (port 8143) and
  Classifier API (port 4433) authentication, as implemented on the feature branch.
  This is the standard PE internal service auth mechanism.
- **D-05:** The script only runs on the PE server where the Puppet server's own
  certificate is trusted by these services. No RBAC token support needed for v1.
- **D-06:** Env var overrides (SSL_CERT_FILE, SSL_KEY_FILE, SSL_CA_FILE) are
  sufficient for cert path customisation. No additional Puppet parameters for cert
  paths.
- **D-07:** Keep the existing rspec-puppet manifest tests from the feature branch
  (parameter compilation, template content validation, boundary checks).
- **D-08:** Defer Ruby unit tests for the collection logic (API mocking, error
  scenarios, retry behaviour) until the codebase stabilises after later phases.
- **D-09:** Ship the existing metric names as-is:
  puppet_orchestrator_job_info, puppet_orchestrator_job_duration_seconds,
  puppet_orchestrator_job_start_timestamp, puppet_orchestrator_job_node_count,
  puppet_orchestrator_jobs_by_state, puppet_orchestrator_plan_info,
  puppet_orchestrator_plan_duration_seconds,
  puppet_orchestrator_plan_start_timestamp, puppet_node_group_info,
  puppet_class_usage, puppet_classes_per_node.
- **D-10:** Label cardinality on job_id is acceptable with the default 50-job limit.
  Users can tune via orchestrator_jobs_limit parameter.

### Claude's Discretion

- Test design approach for Ruby unit tests when they are eventually written
  (extract-and-test vs refactor into lib)
- Conflict resolution details during patch application
- Any minor code cleanup needed to align feature branch code with
  self_service_graphs conventions

### Deferred Ideas (OUT OF SCOPE)

- RBAC token authentication as an alternative to SSL client certs
- Ruby unit tests for collection logic (API mocking, error scenarios, retry
  behaviour)
- Cardinality warnings when job count exceeds thresholds

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-01 | Collects orchestrator job metrics (duration, status, node count) | `collect_orchestrator_jobs` on feature branch (+80 lines), emits 5 metric types |
| ORCH-02 | Collects orchestrator plan metrics (duration, status) | `collect_orchestrator_plans` on feature branch (+60 lines), emits 4 metric types |
| ORCH-03 | Collects node group classification metrics with hierarchy | `collect_node_groups` on feature branch (+90 lines), DFS tree traversal |
| ORCH-04 | Collects class usage metrics (count of nodes using each class) | `collect_class_usage` on feature branch (+30 lines), PQL resources query |
| ORCH-05 | Orchestrator/classification disabled by default, enabled via params | Boolean params default `false` in data/common.yaml |
| TEST-02 | Tests cover orchestrator and classification metric collection | 108 lines of rspec-puppet tests on feature branch |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- UK spelling throughout
- Markdown must pass markdownlint without overrides
- No em dashes (use commas or parentheses)
- Ruby: `frozen_string_literal: true`, 200-char line length,
  `braces_for_chaining`, compact class style
- Puppet: snake_case params, explicit types, arrow-aligned attributes,
  `epp()` not `template()`
- EPP: typed parameter block at top
- Error handling: validate early, `fail()` for business logic,
  `collect_with_error_handling` for runtime isolation
- GSD workflow enforcement for all file changes

## Architecture Patterns

### Patch Application Strategy

The feature branch diff must be split per-file and applied individually because
`self_service_graphs` has diverged from `main`. Here is what needs resolving in
each file:

#### manifests/init.pp (Conflicts Expected)

| Section | Feature Branch Expects | self_service_graphs Has | Resolution |
|---------|----------------------|------------------------|------------|
| Param docs | After `scm_log_file` docs | `custom_queries` docs there | Add after custom_queries docs |
| Param declarations | After `scm_log_file` param | `custom_queries` params there | Add after custom_queries_file |
| EPP hash | After `scm_dir` key | `custom_queries_file` key there | Add after custom_queries_file |
| Examples | After existing examples | Custom queries example there | Add after custom queries example |

[VERIFIED: git diff and file reads of both branches]

#### templates/puppet_data_connector_enhancer.epp (Conflicts Expected)

| Section | Feature Branch Expects | self_service_graphs Has | Resolution |
|---------|----------------------|------------------------|------------|
| EPP params | After `String $scm_dir` | `$custom_queries_file` there | Add after `$custom_queries_file` |
| `generate_metrics` | After `infrastructure_config` | `custom_metrics` there | Add after `custom_metrics` |
| `load_configuration` | After `cd4pe_server` key | `custom_queries_file` there | Add after `custom_queries_file` |
| Base URL helpers | After `infra_assistant_base_url` | No conflict | Clean insertion |
| `fetch_json_from_orchestrator` | New method | No conflict | Insert after existing fetch method |
| Collector methods | New methods | `collect_custom_metrics` exists | Insert before custom_metrics |
| `header_metrics` hash | Splits hash with `merge!` | Single hash | Restructure needed |

[VERIFIED: line-by-line comparison of both branches]

#### data/common.yaml (Clean Apply Expected)

The feature branch appends 7 lines at the end. The `self_service_graphs` branch
only differs from main by 3 trailing newlines in this file. Patch should apply
cleanly or with trivial offset. [VERIFIED: git diff]

#### spec/classes/puppet_data_connector_enhancer_spec.rb (Likely Clean)

The feature branch inserts 108 lines of new test contexts before
`context 'resource ordering'`. The `self_service_graphs` branch has additional
custom_queries tests in a different context block. Patch should apply with offset
adjustment only. [VERIFIED: git diff, feature branch inserts at line 331 in the
original]

### Key Code Patterns from Feature Branch

#### SSL Client Certificate HTTP Client

```ruby
# Source: feature/orchestrator-metrics branch
def fetch_json_from_orchestrator(uri_str, params = {})
  # Uses Net::HTTP with OpenSSL client certificates
  # Cert paths from @config[:ssl_cert_file], @config[:ssl_key_file], @config[:ssl_ca_file]
  # Retry with 1.5x exponential backoff
  # Raises MetricsCollectionError on failure (caught by collect_with_error_handling)
end
```

This method mirrors `fetch_json_from_puppetdb` but adds SSL client cert auth. It
is reused for both Orchestrator API (port 8143) and Classifier API (port 4433)
calls. `require 'openssl'` is already present at line 24 of the current template,
so no additional require is needed. [VERIFIED: feature branch code review,
current branch line 24]

#### Feature Flag Conditional Collection

```ruby
# Source: feature/orchestrator-metrics branch
if @config[:enable_orchestrator_metrics]
  collect_with_error_handling('orchestrator_jobs') { collect_orchestrator_jobs }
  collect_with_error_handling('orchestrator_plans') { collect_orchestrator_plans }
end

if @config[:enable_classification_metrics]
  collect_with_error_handling('node_groups') { collect_node_groups }
  collect_with_error_handling('class_usage') { collect_class_usage }
end
```

Both feature flags default to `false` in Hiera data and are passed through EPP
params from the manifest. [VERIFIED: feature branch code review]

#### Header Metrics Restructuring

The feature branch changes the `header_metrics` hash from a single literal to a
base hash followed by conditional `merge!` calls. This is the trickiest conflict
because the `self_service_graphs` branch still uses a single hash. The merge
needs to:

1. Close the base hash before the exporter health metrics
2. Add conditional orchestrator metric headers via `merge!`
3. Add conditional classification metric headers via `merge!`
4. Re-open with a final `merge!` for the exporter health metrics

[VERIFIED: feature branch diff review]

### Metric Names and Labels (from D-09)

#### Orchestrator Job Metrics

| Metric | Labels | Value |
|--------|--------|-------|
| `puppet_orchestrator_job_info` | job_id, task_name, command, environment, owner, state | 1 |
| `puppet_orchestrator_job_duration_seconds` | job_id, task_name | seconds |
| `puppet_orchestrator_job_start_timestamp` | job_id, task_name | unix ts |
| `puppet_orchestrator_job_node_count` | job_id, task_name | integer |
| `puppet_orchestrator_job_status_total` | state | count |

#### Orchestrator Plan Metrics

| Metric | Labels | Value |
|--------|--------|-------|
| `puppet_orchestrator_plan_info` | job_id, plan_name, environment, owner, state | 1 |
| `puppet_orchestrator_plan_duration_seconds` | job_id, plan_name | seconds |
| `puppet_orchestrator_plan_start_timestamp` | job_id, plan_name | unix ts |
| `puppet_orchestrator_plan_status_total` | state | count |

#### Classification Metrics

| Metric | Labels | Value |
|--------|--------|-------|
| `puppet_node_group_info` | group_uuid, group_name, display_name, sort_order, environment, parent_group, depth, has_rules | class_count |
| `puppet_node_group_edge` | source_name, target_name | 1 |
| `puppet_class_usage_total` | class_name | node count |
| `puppet_classes_per_node` | node | class count |

[VERIFIED: feature branch code review]

**Note:** D-09 lists `puppet_orchestrator_jobs_by_state` but the actual code uses
`puppet_orchestrator_job_status_total`. Similarly, D-09 lists `puppet_class_usage`
but the code uses `puppet_class_usage_total`. The code is the source of truth per
D-09's intent to "ship existing metric names as-is".

### API Endpoints Used

| API | Endpoint | Port | Auth |
|-----|----------|------|------|
| PE Orchestrator | `/orchestrator/v1/jobs` | 8143 | SSL client cert |
| PE Orchestrator | `/orchestrator/v1/plan_jobs` | 8143 | SSL client cert |
| Node Classifier | `/classifier-api/v1/groups` | 4433 | SSL client cert |
| PuppetDB | `/pdb/query/v4` (class usage) | 8080 | HTTP (existing) |

[VERIFIED: feature branch code] [ASSUMED: port numbers match standard PE defaults]

### SSL Certificate Paths

Default paths derived from puppet_server certname:

- Cert: `/etc/puppetlabs/puppet/ssl/certs/<certname>.pem`
- Key: `/etc/puppetlabs/puppet/ssl/private_keys/<certname>.pem`
- CA: `/etc/puppetlabs/puppet/ssl/certs/ca.pem`

All overridable via environment variables (D-06). [VERIFIED: feature branch code]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSL client cert auth | Custom OpenSSL wrapper | Net::HTTP with cert/key/ca_file | Already on feature branch, stdlib pattern |
| Retry logic | New retry mechanism | Existing exponential backoff | Established pattern from fetch_json_from_puppetdb |
| Error isolation | Per-collector try/catch | `collect_with_error_handling` | All collectors already use it |
| Tree traversal display | Custom indentation | Existing DFS with prefix tracking | Feature branch already implements it |

## Common Pitfalls

### Pitfall 1: Patch Context Mismatch

**What goes wrong:** `git apply` fails because the patch context lines reference
code from `main` that has been modified on `self_service_graphs`.
**Why it happens:** The custom queries commit (`648aea4`) added parameters, EPP
params, config keys, and collectors in the same locations where the orchestrator
patches need to insert.
**How to avoid:** Use `git diff main...origin/feature/orchestrator-metrics -- <file>`
per file, apply with `--3way` flag for conflict markers, or apply manually by
reading the diff and inserting code at the correct locations on the current branch.
**Warning signs:** `git apply` exits non-zero, "patch does not apply" errors.

### Pitfall 2: Header Metrics Hash Restructuring

**What goes wrong:** The feature branch splits the `header_metrics` hash into a
base hash plus conditional `merge!` blocks. If you insert the
orchestrator/classification blocks without restructuring the hash closure, you get
a Ruby syntax error.
**Why it happens:** The current branch has a single `header_metrics = { ... }`
hash. The feature branch closes it early and uses `header_metrics.merge!({ ... })`
conditionally.
**How to avoid:** Close the base `header_metrics` hash before the exporter health
metrics. Add conditional `merge!` blocks for orchestrator and classification. Then
add a final `merge!` for the exporter health metrics.
**Warning signs:** `SyntaxError` when the generated Ruby script runs, or missing
metric headers in output.

### Pitfall 3: EPP Parameter Type Mismatch

**What goes wrong:** New EPP parameters added without matching types in the
parameter block, or manifest passes wrong types.
**Why it happens:** The EPP parameter block at the top of the template must match
exactly what the manifest passes in the `epp()` call.
**How to avoid:** Verify that every new EPP parameter (Boolean, Integer) has both:
(a) a declaration in the EPP parameter block, and (b) a matching key in the
manifest's `epp()` call hash.
**Warning signs:** Puppet catalog compilation fails with "EPP parameter mismatch".

### Pitfall 4: Test Insertion Point

**What goes wrong:** Tests are inserted at the wrong location in the spec file,
breaking RSpec `describe`/`context` nesting.
**Why it happens:** The custom queries tests on `self_service_graphs` may have
shifted line numbers for the `context 'resource ordering'` block where the feature
branch tests are inserted before.
**How to avoid:** Find the `context 'resource ordering'` block in the current spec
file and insert the orchestrator/classification test contexts immediately before it.
**Warning signs:** RSpec syntax errors, "unexpected end" or context nesting
mismatches.

## Code Examples

### Generating Per-File Patches

```bash
# Source: standard git workflow [VERIFIED: git documentation]
for file in manifests/init.pp templates/puppet_data_connector_enhancer.epp \
            data/common.yaml spec/classes/puppet_data_connector_enhancer_spec.rb; do
  git diff main...origin/feature/orchestrator-metrics -- "$file" \
    > "/tmp/patch-$(basename $file).patch"
done
```

### Applying with Three-Way Merge

```bash
# Source: standard git workflow [VERIFIED: git documentation]
# --3way creates conflict markers when context does not match
git apply --3way /tmp/patch-init.pp.patch
```

### Manual Insertion Points on self_service_graphs

```puppet
# manifests/init.pp - Parameter declarations
# Insert AFTER line 157 (custom_queries_file parameter):
  Boolean $enable_orchestrator_metrics                  = false,
  Integer[1, 200] $orchestrator_jobs_limit              = 50,
  Boolean $enable_classification_metrics                = false,
```

```puppet
# manifests/init.pp - EPP hash (around line 239-240)
# Insert AFTER 'custom_queries_file' key:
        'enable_orchestrator_metrics'  => $enable_orchestrator_metrics,
        'orchestrator_jobs_limit'      => $orchestrator_jobs_limit,
        'enable_classification_metrics' => $enable_classification_metrics,
```

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PDK | Test execution | Docker alias | 3.4.0 (via Docker) | `bundle exec rake spec` |
| Ruby | Test execution | Yes | 3.2.5 (Bolt ruby) | PDK docker container |
| Bundler | Dependencies | Yes | 2.7.1 | PDK docker container |
| git | Patch generation | Yes | (system) | None needed |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:**

- PDK is a Docker alias, not a native install. For spec tests,
  `bundle exec rake spec` or running PDK via Docker both work.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | PE Orchestrator API on port 8143 by default | API Endpoints | Env var override mitigates |
| A2 | Node Classifier API on port 4433 by default | API Endpoints | Env var override mitigates |

## Open Questions (RESOLVED)

1. **Metric name discrepancy between D-09 and code**
   - What we know: D-09 says `puppet_orchestrator_jobs_by_state` but code uses
     `puppet_orchestrator_job_status_total`. D-09 says `puppet_class_usage` but
     code uses `puppet_class_usage_total`.
   - What is unclear: Whether D-09 was written from memory or from the code
   - Recommendation: Ship the code's names (D-09 says "as-is" meaning the code)
   - RESOLVED: Code names are authoritative per D-09 intent. Ship `puppet_orchestrator_job_status_total` and `puppet_class_usage_total`.

## Sources

### Primary (HIGH confidence)

- Feature branch code: `git diff main...origin/feature/orchestrator-metrics`
  (all 4 target files reviewed line by line)
- Current branch code: direct file reads of manifests/init.pp,
  templates/puppet_data_connector_enhancer.epp, data/common.yaml,
  spec/classes/puppet_data_connector_enhancer_spec.rb
- Branch divergence: `git diff main..self_service_graphs` and `git show 648aea4`
  confirming custom queries code already present
- OpenSSL availability: `require 'openssl'` confirmed at line 24 of current EPP
  template

### Secondary (MEDIUM confidence)

- PE API port defaults (8143 orchestrator, 4433 classifier) from established PE
  documentation patterns

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH (no new dependencies, existing Puppet module patterns)
- Architecture: HIGH (all code reviewed on both branches, conflict points mapped)
- Pitfalls: HIGH (conflicts are predictable from diff analysis, not speculative)

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable, no external dependencies changing)
