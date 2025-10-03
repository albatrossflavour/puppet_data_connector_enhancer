# puppet_data_connector_enhancer

[![Puppet Forge](https://img.shields.io/puppetforge/v/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Puppet Forge - endorsement](https://img.shields.io/puppetforge/e/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)

## Table of Contents

1. [Description](#description)
2. [Setup](#setup)
   - [Requirements](#requirements)
   - [Installation](#installation)
3. [Usage](#usage)
   - [Basic usage](#basic-usage)
   - [SCM CIS score collection](#scm-cis-score-collection)
   - [Grafana dashboards](#grafana-dashboards)
4. [Reference](#reference)
5. [Limitations](#limitations)
6. [Development](#development)
7. [Contributors](#contributors)

## Description

The `puppet_data_connector_enhancer` module extends Puppet's [puppet_data_connector](https://forge.puppet.com/modules/puppetlabs/puppet_data_connector) by collecting comprehensive infrastructure metrics and delivering them to the data connector dropzone for Prometheus consumption.

**Key features:**

- **Enhanced metrics**: Node counts, OS distribution, configuration versions, patch status, and Infrastructure Assistant AI token usage
- **SCM integration**: Optional CIS compliance score collection and distribution via PuppetDB exported resources
- **Health monitoring**: Export job status metrics for Alertmanager integration
- **Grafana dashboards**: Pre-built dashboards for visualising all collected metrics

## Setup

### Requirements

- Puppet Enterprise 2021.7+ or Puppet Platform 7.24+
- [puppet_data_connector](https://forge.puppet.com/modules/puppetlabs/puppet_data_connector) module installed and configured
- PuppetDB API access (typically port 8080/8081)
- For SCM integration: Puppet Security Compliance Management v3.x+

**Dependencies:**

- `puppetlabs/stdlib` (>= 9.0.0 < 10.0.0)
- `puppet/systemd` (>= 4.0.0 < 8.0.0)

### Installation

Install from the Puppet Forge:

```bash
puppet module install albatrossflavour-puppet_data_connector_enhancer
```

Or add to your Puppetfile:

```ruby
mod 'albatrossflavour-puppet_data_connector_enhancer', :latest
```

## Usage

### Basic usage

Include the module with default settings:

```puppet
include puppet_data_connector_enhancer
```

This will:
- Install the metrics collection script to `/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer`
- Create a systemd timer running every 30 minutes
- Automatically discover the dropzone path from your `puppet_data_connector` configuration
- Connect to PuppetDB on `localhost:8080` using HTTP

### SCM CIS score collection

Enable optional CIS compliance score collection from Security Compliance Management:

```puppet
# On PE primary server only - configure SCM collection
class { 'puppet_data_connector_enhancer':
  enable_scm_collection => true,
  scm_server            => 'scm.example.com',
  scm_auth              => Sensitive(lookup('scm_api_token')),
}

# On all managed nodes - collect CIS score facts
include puppet_data_connector_enhancer::client
```

**Important:**
- The main `puppet_data_connector_enhancer` class should **only** be applied to the PE primary server
- The `puppet_data_connector_enhancer::client` class must be declared on **all nodes** you want to collect CIS score facts for

**How it works:**

1. **Server-side** (PE primary server only):
   - Systemd timer runs `/opt/puppetlabs/puppet_data_connector_enhancer/export_and_download_cis`
   - Script polls SCM API, downloads CIS summary report, parses CSV
   - Exports file resources to PuppetDB (one per node)
   - Writes status JSON for Prometheus health monitoring

2. **Client-side** (all managed nodes):
   - `puppet_data_connector_enhancer::client` class collects exported resource from PuppetDB tagged for this specific node
   - Writes to `/opt/puppetlabs/facter/facts.d/cis_score.yaml` (or `C:/ProgramData/PuppetLabs/facter/facts.d/cis_score.yaml` on Windows)
   - Facter loads as structured fact on next Puppet run

3. **Metrics collection**:
   - Main script reads status file and `cis_score` facts
   - Generates Prometheus metrics including export health status

**Available SCM parameters:**

| Parameter               | Type                          | Default                                    |
| ----------------------- | ----------------------------- | ------------------------------------------ |
| `enable_scm_collection` | Boolean                       | `false`                                    |
| `scm_server`            | Optional[Stdlib::Fqdn]        | `undef` (required if enabled)              |
| `scm_auth`              | Optional[Sensitive[String]]   | `undef` (required if enabled)              |
| `scm_dir`               | Stdlib::Absolutepath          | `/opt/puppetlabs/puppet_data_connector_enhancer` |
| `scm_export_retention`  | Integer[1]                    | `8`                                        |
| `scm_poll_interval`     | Integer[1]                    | `30` (seconds)                             |
| `scm_max_wait_time`     | Integer[1]                    | `900` (seconds)                            |
| `scm_timer_interval`    | Pattern[/^.+$/]               | `*:0/30` (every 30 minutes)                |
| `scm_log_file`          | Stdlib::Absolutepath          | `/var/log/puppetlabs/puppet_data_connector_enhancer_scm.log` |

**SCM health metrics for Alertmanager:**

```prometheus
# Export job status (1 = success, 0 = failed)
puppet_scm_export_success

# Timestamps for staleness detection
puppet_scm_export_last_run_timestamp
puppet_scm_export_last_success_timestamp

# Performance and volume metrics
puppet_scm_export_duration_seconds
puppet_scm_export_nodes_count

# Metadata
puppet_scm_export_info{export_id="..."}
```

**Example alert rules:**

```yaml
# Alert if export hasn't run in 2 hours
- alert: SCMExportStale
  expr: time() - puppet_scm_export_last_run_timestamp > 7200

# Alert if export is failing
- alert: SCMExportFailing
  expr: puppet_scm_export_success == 0
```

### Grafana dashboards

The module includes pre-built Grafana dashboards for visualising all collected metrics.

![Overview Dashboard](https://raw.githubusercontent.com/albatrossflavour/puppet_data_connector_enhancer/main/images/overview%20dashboard.png)

**Available dashboards:**

| Dashboard | Description |
| --------- | ----------- |
| `puppet_dashboards.json` | Main navigation dashboard |
| `puppet_status.json` | Puppet run status and node health |
| `puppet_node_detail.json` | Detailed node metrics |
| `puppet_os_overview.json` | OS distribution and versions |
| `puppet_patching_status.json` | Patch management overview |
| `puppet_patching_detail.json` | Package update details |
| `puppet_patching_blocked.json` | Blocked patching operations |
| `puppet_restart_overview.json` | Restart requirements |
| `puppet_cis.json` | CIS compliance scores |

**📸 [View Dashboard Gallery →](https://github.com/albatrossflavour/puppet_data_connector_enhancer/blob/main/DASHBOARDS.md)**

**Quick start:**

1. Copy JSON files from: `puppet_data_connector_enhancer/files/*.json`
2. In Grafana: **Dashboards** → **Import**
3. Upload JSON file or paste contents
4. Select Prometheus data source
5. Click **Import**

All dashboards support infrastructure server filters for multi-environment deployments.

## Reference

See [REFERENCE.md](REFERENCE.md) for detailed parameter documentation and function references.

**Key parameters:**

| Parameter           | Type                          | Default                         |
| ------------------- | ----------------------------- | ------------------------------- |
| `ensure`            | Enum['present', 'absent']     | `'present'`                     |
| `script_path`       | Optional[Stdlib::Absolutepath] | `${scm_dir}/puppet_data_connector_enhancer` |
| `timer_interval`    | String[1]                     | `'*:0/30'`                      |
| `http_timeout`      | Integer[1, 300]               | `5`                             |
| `log_level`         | Enum['DEBUG', 'INFO', 'WARN', 'ERROR'] | `'INFO'`           |
| `dropzone`          | Stdlib::Absolutepath          | Discovered from `puppet_data_connector` |

**Collected metrics:**

The module collects 20+ metric types including:
- `puppet_configuration_version` - Per-node configuration version
- `puppet_node_count` - Nodes by environment
- `puppet_state_overview` - PuppetDB statistics
- `puppet_node_os` - OS details per node
- `puppet_patching_data` - Available updates
- `puppet_cis_compliance_score` - CIS scores (base and adjusted)
- `puppet_scm_export_*` - SCM export health metrics
- `puppet_infra_assistant_tokens_total` - AI token usage
- `puppet_exporter_*` - Collection health metrics

## Limitations

**Operating system support:**

- Red Hat family: RHEL 7-9, CentOS 7-9, Rocky Linux 8+, AlmaLinux 8+
- Debian family: Debian 10-12, Ubuntu 18.04-22.04
- SUSE family: SLES 12-15

**Known limitations:**

- Requires PE-compatible Ruby environment
- Network access to PuppetDB and Infrastructure Assistant APIs
- SCM export script requires `unzip` and `gzip` utilities on PE server
- Infrastructure Assistant metrics require PE 2023.8+

## Development

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

**Testing:**

```bash
pdk validate       # Syntax and style checks
pdk test unit      # RSpec unit tests
pdk build          # Build module package
```

**Code standards:**

- [Puppet Development Kit (PDK)](https://puppet.com/docs/pdk/)
- [Puppet code style guide](https://puppet.com/docs/puppet/latest/style_guide.html)
- [Puppet Strings documentation](https://puppet.com/docs/puppet/latest/puppet_strings.html)

## Contributors

See [CONTRIBUTORS.md](CONTRIBUTORS.md) for the full list of contributors.

**Support:**

- **Issues**: [GitHub Issues](https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer/issues)
- **Pull Requests**: [GitHub PRs](https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer/pulls)

---

Copyright 2025 albatrossflavour and contributors

Licensed under the Apache License, Version 2.0
