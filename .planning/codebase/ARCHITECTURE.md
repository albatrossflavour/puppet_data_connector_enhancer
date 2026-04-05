# Architecture

**Analysis Date:** 2026-04-05

## Pattern Overview

**Overall:** Puppet Module (PDK-structured) with server/client role separation

**Key Characteristics:**

- The module follows the standard Puppet Enterprise module pattern: a main class
  (`init.pp`) acts as the coordinator, with private subclasses for specific roles
- The Puppet server runs the heavy lifting (metrics collection, SCM export); all
  managed nodes are clients that collect exported resources from PuppetDB
- Configuration is baked into deployed scripts at compile time via EPP templates,
  so no runtime config files are needed on-disk
- External integrations (PuppetDB, Infrastructure Assistant API, SCM) are all
  reached over HTTP/HTTPS from the deployed Ruby scripts

## Layers

**Puppet Manifest Layer:**

- Purpose: Declares resources, validates parameters, orchestrates deployment
- Location: `manifests/`
- Contains: Class declarations, file resources, systemd unit management
- Depends on: EPP templates, Puppet functions, `puppetlabs/stdlib`, `puppet/systemd`
- Used by: Puppet agent catalog compilation

**EPP Template Layer:**

- Purpose: Generates the actual Ruby scripts deployed to disk with baked-in config
- Location: `templates/`
- Contains: Ruby script bodies with EPP variable interpolation for config values
- Depends on: Parameters passed from manifest classes at compile time
- Used by: `manifests/init.pp` and `manifests/scm.pp` via `epp()` function calls

**Ruby Function Layer:**

- Purpose: Puppet functions that run on the Puppet master during catalog compilation
- Location: `lib/puppet/functions/puppet_data_connector_enhancer/`
- Contains: `parse_csv.rb` (parses SCM CIS score CSV into a hash for exported resources)
- Depends on: Ruby stdlib `csv`
- Used by: `manifests/scm.pp` to build exported file resources per node

**Data Layer:**

- Purpose: Hiera defaults for module parameters
- Location: `data/common.yaml`, `hiera.yaml`
- Contains: Default values for SCM configuration parameters
- Depends on: Nothing
- Used by: Puppet Hiera during parameter lookup

**Deployed Script Layer (runtime):**

- Purpose: The actual scripts that execute on the PE server at runtime
- Location: Deployed to `$scm_dir` (default `/opt/puppetlabs/puppet_data_connector_enhancer/`)
- Contains: `puppet_data_connector_enhancer` (metrics collector), `export_and_download_cis` (SCM exporter)
- Depends on: PuppetDB API, Infrastructure Assistant API, SCM API
- Used by: systemd timers (run periodically, not by Puppet agent)

## Data Flow

**Core Metrics Collection Flow:**

1. systemd timer fires `puppet-data-connector-enhancer.timer` on schedule
2. systemd executes `puppet_data_connector_enhancer` Ruby script with `-o <dropzone_file>` flag
3. Script queries PuppetDB API (`:8080`) for node counts, state overview, OS info, patching, CIS scores
4. Script queries Infrastructure Assistant API (`:8145`) for AI token usage
5. Script writes Prometheus-format metrics to `$dropzone/$output_filename` (default `puppet_enhanced_metrics.prom`)
6. `puppetlabs/puppet_data_connector` module picks up the `.prom` file from the dropzone

**SCM CIS Score Distribution Flow (server-side):**

1. systemd timer fires `puppet-scm-export.timer`
2. `export_and_download_cis` script calls SCM API to create a compliance export job
3. Script polls SCM API until the export completes (with configurable timeout/retry)
4. Script downloads `Summary_Report_API.csv` to `$scm_dir/score_data/`
5. On next Puppet run, `manifests/scm.pp` calls `parse_csv()` function during catalog compilation
6. `parse_csv()` reads the CSV and returns a hash keyed by certname
7. `scm.pp` iterates the hash and exports a `@@file` resource per node to PuppetDB
8. Each exported resource is tagged with `cis_score_<certname>` for targeted collection

**CIS Score Fact Distribution Flow (client-side):**

1. `manifests/client.pp` runs on all managed nodes when `enable_scm_collection` is true
2. It collects the exported file resource tagged for `trusted['certname']`
3. Resource path and ownership are overridden per OS family (Linux vs Windows)
4. Facter loads the YAML file from `facts.d/` as the `cis_score` structured fact on the next run
5. The fact is then available to the metrics collection script via PuppetDB

**State Management:**

- No application state is held in Puppet manifests; all state is on-disk (CSV files, `.prom` output)
- Deduplication of Prometheus metrics is handled in-memory within the Ruby script's `@seen_metrics` Set
- SCM export retention is managed by the export script itself (configurable via `$scm_export_retention`)

## Key Abstractions

**`PrometheusMetricsGenerator` (Ruby class):**

- Purpose: Encapsulates all metrics collection and Prometheus output formatting
- Location: `templates/puppet_data_connector_enhancer.epp` (generated at compile time)
- Pattern: Collect-then-output, with error isolation per collection type via `collect_with_error_handling`

**Exported Resources (`@@file`):**

- Purpose: Distributes per-node CIS score data from the PE server to all managed nodes via PuppetDB
- Pattern: Server exports tagged resources; clients collect using the virtual resource collector `<<| |>>`
- Key files: `manifests/scm.pp` (exporter), `manifests/client.pp` (collector)

**`parse_csv` Puppet Function:**

- Purpose: Bridges the gap between the on-disk CSV from SCM and Puppet's resource iteration
- Location: `lib/puppet/functions/puppet_data_connector_enhancer/parse_csv.rb`
- Pattern: Returns empty hash on missing file (graceful degradation), raises `Puppet::ParseError` on malformed data

## Entry Points

**`puppet_data_connector_enhancer` class:**

- Location: `manifests/init.pp`
- Triggers: `include puppet_data_connector_enhancer` or `class { ... }` in a node's catalog
- Responsibilities: Parameter validation, directory creation, script deployment, systemd timer management, conditional subclass inclusion

**`puppet_data_connector_enhancer::scm` class:**

- Location: `manifests/scm.pp`
- Triggers: Included by `init.pp` when `$enable_scm_collection` is true AND the node is the PE server
- Responsibilities: SCM script deployment, SCM systemd timer, CSV parsing, exported resource generation

**`puppet_data_connector_enhancer::client` class:**

- Location: `manifests/client.pp`
- Triggers: Included by `init.pp` on all nodes when `$enable_scm_collection` is true
- Responsibilities: Collecting the correct exported file resource for this node's CIS score fact

## Error Handling

**Strategy:** Fail loudly at compile time for configuration errors; degrade gracefully at runtime for missing data

**Patterns:**

- `init.pp` calls `fail()` immediately if `enable_scm_collection` is true but `scm_server`/`scm_auth` are unset
- `parse_csv.rb` logs a warning and returns `{}` when the CSV does not yet exist (first run before SCM export runs)
- `parse_csv.rb` raises `Puppet::ParseError` on malformed CSV, failing catalog compilation
- The deployed metrics script wraps each collection type in `collect_with_error_handling` so a single API failure does not abort the entire metrics run
- HTTP retries with configurable backoff are built into both deployed scripts

## Cross-Cutting Concerns

**Logging:** The metrics script uses Ruby `Logger` to STDERR (when writing to file) or STDOUT. Log level is baked in at compile time but overridable via `LOG_LEVEL` env var. The SCM export script logs to a dedicated file (`$scm_log_file`).

**Validation:** Puppet type system enforces parameter constraints at compile time (e.g., `Enum`, `Integer[1, 300]`, `Stdlib::Absolutepath`). Runtime validation in `parse_csv.rb` skips rows missing required fields.

**Authentication:** SCM API token is handled as `Sensitive[String[1]]` throughout the Puppet manifest layer, preventing exposure in logs. The token is baked into the deployed script with mode `0700` (owner `pe-puppet` only).

**Ownership:** All deployed files and directories are owned by `pe-puppet:pe-puppet`. The `$scm_dir` base directory is created by `init.pp` before subclasses attempt to create content inside it.

---

*Architecture analysis: 2026-04-05*
