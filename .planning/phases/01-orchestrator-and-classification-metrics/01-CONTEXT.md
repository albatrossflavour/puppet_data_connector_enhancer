# Phase 1: Orchestrator and Classification Metrics - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Merge the existing orchestrator and classification metrics from the feature/orchestrator-metrics branch into self_service_graphs. Validate the implementation, ensure manifest tests pass, and ship PE infrastructure visibility. No new collection logic is developed in this phase, just integration of existing work.

</domain>

<decisions>
## Implementation Decisions

### Merge strategy
- **D-01:** Extract the cumulative diff from feature/orchestrator-metrics as patches and apply manually to self_service_graphs. Do not use git merge or cherry-pick.
- **D-02:** Skip the CHANGELOG.md entries from the feature branch. Fresh changelog entries will be written at release time to reflect the final state.
- **D-03:** Only bring across the orchestrator/classification changes (manifests/init.pp, templates/puppet_data_connector_enhancer.epp, data/common.yaml, spec/classes/puppet_data_connector_enhancer_spec.rb). Skip version bumps and README fixes from the feature branch.

### Auth approach
- **D-04:** Use SSL client certificates for Orchestrator API (port 8143) and Classifier API (port 4433) authentication, as implemented on the feature branch. This is the standard PE internal service auth mechanism.
- **D-05:** The script only runs on the PE server where the Puppet server's own certificate is trusted by these services. No RBAC token support needed for v1.
- **D-06:** Env var overrides (SSL_CERT_FILE, SSL_KEY_FILE, SSL_CA_FILE) are sufficient for cert path customisation. No additional Puppet parameters for cert paths.

### Test coverage
- **D-07:** Keep the existing rspec-puppet manifest tests from the feature branch (parameter compilation, template content validation, boundary checks).
- **D-08:** Defer Ruby unit tests for the collection logic (API mocking, error scenarios, retry behaviour) until the codebase stabilises after later phases. Writing tests for code that is about to change significantly wastes effort.

### Metric naming
- **D-09:** Ship the existing metric names as-is: puppet_orchestrator_job_info, puppet_orchestrator_job_duration_seconds, puppet_orchestrator_job_start_timestamp, puppet_orchestrator_job_node_count, puppet_orchestrator_jobs_by_state, puppet_orchestrator_plan_info, puppet_orchestrator_plan_duration_seconds, puppet_orchestrator_plan_start_timestamp, puppet_node_group_info, puppet_class_usage, puppet_classes_per_node.
- **D-10:** Label cardinality on job_id is acceptable with the default 50-job limit. Users can tune via orchestrator_jobs_limit parameter.

### Claude's Discretion
- Test design approach for Ruby unit tests when they are eventually written (extract-and-test vs refactor into lib)
- Conflict resolution details during patch application
- Any minor code cleanup needed to align feature branch code with self_service_graphs conventions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Feature branch (source of truth for existing implementation)
- `remotes/origin/feature/orchestrator-metrics` -- Branch containing all orchestrator and classification metric code to be merged

### Module manifests
- `manifests/init.pp` -- Main class with new parameters (enable_orchestrator_metrics, orchestrator_jobs_limit, enable_classification_metrics)

### Collection script template
- `templates/puppet_data_connector_enhancer.epp` -- EPP template containing the orchestrator/classification Ruby collection logic (+423 lines on feature branch)

### Hiera defaults
- `data/common.yaml` -- Default parameter values for new orchestrator/classification settings

### Existing tests
- `spec/classes/puppet_data_connector_enhancer_spec.rb` -- rspec-puppet tests including orchestrator/classification parameter tests (+108 lines on feature branch)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fetch_json_from_orchestrator` method on feature branch: HTTP client with SSL client cert auth, retry logic, error handling. Can be reused for both Orchestrator and Classifier APIs.
- `collect_with_error_handling` wrapper: existing pattern for isolating per-collector failures. Orchestrator/classification collectors already use this.
- `add_metric` method: existing metric formatting and deduplication via `@seen_metrics` Set.

### Established Patterns
- EPP template generates a complete Ruby script with baked-in config values at compile time
- Feature flags via Boolean Puppet parameters (enable_orchestrator_metrics, enable_classification_metrics) with conditional collector invocation
- Env var overrides for all config values (allows runtime testing without recompiling)
- HTTP retry with exponential backoff (1.5x multiplier) for API calls

### Integration Points
- New parameters added to init.pp parameter list and passed through to EPP template
- Collectors registered in the `run` method under feature flag conditionals
- Base URLs constructed from host/port/protocol config (orchestrator_base_url, classifier_base_url)
- SSL cert paths derived from puppet_server certname

</code_context>

<specifics>
## Specific Ideas

- Auth may need to change in future (RBAC tokens) but SSL certs are correct for PE server-only operation right now
- Ruby unit testing explicitly deferred to avoid rework -- revisit once the codebase stabilises after Phase 2 or 3

</specifics>

<deferred>
## Deferred Ideas

- RBAC token authentication as an alternative to SSL client certs -- future consideration if the script needs to run from non-PE-server nodes
- Ruby unit tests for collection logic (API mocking, error scenarios, retry behaviour) -- deferred until codebase stabilises
- Cardinality warnings when job count exceeds thresholds -- not needed at v1 default limits

</deferred>

---

*Phase: 01-orchestrator-and-classification-metrics*
*Context gathered: 2026-04-05*
