# External Integrations

**Analysis Date:** 2026-04-05

## APIs & External Services

**PuppetDB:**

- What: Primary data source. All Puppet node, fact, report, and patch data is
  read from PuppetDB's REST API.
- Endpoints consumed (from `templates/puppet_data_connector_enhancer.epp`):
  - `GET /pdb/query/v4/nodes` - Node certname enumeration
  - `GET /pdb/query/v4/reports` - Configuration versions per node
  - `GET /pdb/ext/v1/state-overview` - Node state summary counts
  - `GET /pdb/query/v4/facts/os` - OS family, name, version, architecture
  - `GET /pdb/query/v4/facts/trusted` - Trusted facts (pp_role, pp_datacenter)
  - `GET /pdb/query/v4/facts/pe_patch` - Patch status, counts, blocked state
  - `GET /pdb/query/v4/facts/cis_score` - CIS compliance scores (if SCM
    enabled)
  - `GET /pdb/query/v4` (with PQL) - General node queries
- SDK/Client: Ruby stdlib `net/http` only; no SDK gem
- Auth: None (unauthenticated HTTP by default; HTTPS with SSL verification
  disabled if configured)
- Config: `PUPPETDB_HOST` (default `localhost`), `PUPPETDB_PORT` (default
  `8080`), `PUPPETDB_PROTOCOL` (default `http`)

**Puppet Infrastructure Assistant:**

- What: PE's AI-powered assistant service. Queried for token usage metrics
  (input, output, reasoning counts).
- Endpoint consumed:
  - `GET /status/v1/services?level=debug` - AI service token usage statistics
- SDK/Client: Ruby stdlib `net/http`; SSL verification disabled
- Auth: None (relies on local network access to PE infrastructure)
- Config: `INFRA_ASSISTANT_HOST` (default `localhost`),
  `INFRA_ASSISTANT_PORT` (default `8145`), `INFRA_ASSISTANT_PROTOCOL`
  (default `https`)

**Puppet Security Compliance Management (SCM) API:**

- What: Optional integration. When `enable_scm_collection => true`, the PE
  server polls the SCM API to trigger, download, and parse CIS compliance
  summary reports.
- Endpoints consumed (from `templates/export_and_download_cis.rb.epp`):
  - `POST /api/public/v1/export-job` - Create a new `compliance_status_summary`
    export
  - `GET /api/public/v1/exports` - List exports (used for polling and cleanup)
  - `GET /api/public/v1/export/{id}/file` - Download completed export as ZIP
  - `DELETE /api/public/v1/export/{id}` - Delete old exports (retention
    management)
- SDK/Client: Ruby stdlib `net/http`; SSL verification disabled
  (`VERIFY_NONE`)
- Auth: Bearer token. Passed as `Authorization: Bearer <token>` header.
  Token stored as `Sensitive[String[1]]` in Puppet (`scm_auth` parameter,
  `manifests/init.pp` line 121). Token baked into deployed script at
  `/opt/puppetlabs/puppet_data_connector_enhancer/export_and_download_cis`
  (mode `0700`).
- Config: `scm_server` (FQDN), `scm_auth` (Sensitive token) - both class
  parameters in `manifests/init.pp`

**Puppet Forge:**

- What: Upstream distribution channel. Module published as
  `albatrossflavour-puppet_data_connector_enhancer`.
- SDK/Client: `puppet-blacksmith` ~> 7.0 (release tooling only, development
  dependency)

## Data Storage

**Databases:**

- PuppetDB - Read-only consumer. No direct DB connection; all access via
  PuppetDB REST API. Connection config via environment variables at runtime.

**File Storage:**

- Prometheus dropzone: `/opt/puppetlabs/puppet/prometheus_dropzone/` (default)
  - Output file: `puppet_enhanced_metrics.prom` (Prometheus text format)
  - Owned by `pe-puppet:pe-puppet`, mode `0640`
- SCM score data: `/opt/puppetlabs/puppet_data_connector_enhancer/score_data/`
  - `Summary_Report_API.csv` - Downloaded CIS summary data (mode `0644`)
  - `scm_export_status.json` - Last run status for Prometheus health metrics
- CIS score facts: `/opt/puppetlabs/facter/facts.d/cis_score.yaml` per node
  (written via exported Puppet resources)

**Caching:**

- None. Metrics are generated fresh on each timer invocation.

## Authentication and Identity

**Auth Provider:**

- No centralised auth provider. Three distinct authentication concerns:
  1. PuppetDB: Unauthenticated by default (local HTTP); optional HTTPS with
     verification disabled
  2. Infrastructure Assistant: Unauthenticated (local HTTPS, verification
     disabled)
  3. SCM API: Bearer token passed as Puppet `Sensitive` parameter; embedded in
     deployed script file protected by `0700` permissions

## Monitoring and Observability

**Metrics Output:**

- Prometheus text format written to PE's prometheus dropzone; consumed by
  `puppetlabs/puppet_data_connector` for Grafana dashboards
- Pre-built Grafana dashboard JSON files in `files/`:
  - `puppet_status.json`, `puppet_os_overview.json`,
    `puppet_patching_status.json`, `puppet_patching_detail.json`,
    `puppet_patching_blocked.json`, `puppet_restart_overview.json`,
    `puppet_node_detail.json`, `puppet_cis.json`, `puppet_dashboards.json`

**Error Tracking:**

- No external error tracking service. Errors are captured as Prometheus metrics
  (`puppet_exporter_collection_failed`) with labels for collection name,
  endpoint, and truncated error message. Script continues collecting remaining
  metric types on partial failure.

**Logs:**

- Main metrics script: Logs to STDERR (when writing to file) or STDOUT.
  Log level controlled by `LOG_LEVEL` env var or `log_level` class parameter.
  Journald via systemd service (`StandardOutput=journal`).
- SCM export script: Logs to a configurable file path (`scm_log_file`
  parameter, default `/var/log/puppetlabs/puppet_data_connector_enhancer_scm.log`),
  also captured by journald.

## CI/CD and Deployment

**Hosting:**

- Puppet Forge (`forge.puppet.com`) - module distribution
- GitHub: `https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer`

**CI Pipeline:**

- Not detected in this repository. No GitHub Actions, Jenkins, or Travis
  configuration files present.

## Webhooks and Callbacks

**Incoming:** None.

**Outgoing:** None. All integrations are initiated by the deployed scripts on a
systemd timer schedule.

## Scheduled Execution

**Main metrics collection:**

- Systemd service: `puppet-data-connector-enhancer.service` (oneshot, runs as
  `pe-puppet`)
- Systemd timer: `puppet-data-connector-enhancer.timer`
- Default schedule: `OnCalendar=*:0/30` (every 30 minutes; configurable via
  `timer_interval` parameter)

**SCM CIS export:**

- Systemd timer: `puppet-scm-export.timer` (managed by `puppet/systemd`
  `systemd::timer` resource)
- Default schedule: `OnCalendar=*:0/30` (configurable via `scm_timer_interval`
  parameter)
- Both timers use `Persistent=true` to catch up missed runs after downtime

---

*Integration audit: 2026-04-05*
