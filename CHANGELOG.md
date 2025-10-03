# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-XX-XX

### Added

- **SCM CIS Score Collection**: Optional integration with Puppet Security Compliance Management
  - Server-side export/download script with polling and retry logic
  - CSV parsing and distribution via PuppetDB exported resources
  - Client-side collection as structured facts
  - Systemd timer for automated SCM exports (replaces cron)
  - Configurable retention, polling intervals, and timeouts
- **SCM Export Health Metrics**: Prometheus metrics for monitoring export job status
  - `puppet_scm_export_success` - Export success/failure status (for alerting)
  - `puppet_scm_export_last_run_timestamp` - Last run timestamp
  - `puppet_scm_export_last_success_timestamp` - Last successful run
  - `puppet_scm_export_duration_seconds` - Export duration
  - `puppet_scm_export_nodes_count` - Number of nodes exported
  - `puppet_scm_export_info` - Export metadata with ID
- **Grafana Dashboards**: Pre-built dashboards for all metrics
  - Main navigation dashboard
  - CIS compliance tracking
  - Node detail views
  - OS overview
  - Patch management (overview, groups, detail, blocked)
  - Restart/reboot requirements
- **Documentation**:
  - Comprehensive dashboard gallery (DASHBOARDS.md) with screenshots
  - Contributors file (CONTRIBUTORS.md) recognising all project contributors
  - Apache 2.0 LICENSE file

### Changed

- **Script Locations**: Consolidated all scripts under `${scm_dir}` (default: `/opt/puppetlabs/puppet_data_connector_enhancer`)
  - Main script: `${scm_dir}/puppet_data_connector_enhancer` (was `/usr/local/bin/puppet_data_connector_enhancer.rb`)
  - SCM export script: `${scm_dir}/export_and_download_cis` (no `.rb` extension)
  - Scripts now stored together for easier management
- **User Permissions**: All scripts now run as `pe-puppet` user instead of `root` (improved security)
- **Main Timer**: Migrated from cron to systemd timer for main metrics collection
- **CSV Parsing**: Replaced string split with Ruby CSV library for robust parsing
- **Error Handling**: Added retry logic with exponential backoff for SCM API calls (3 retries: 60s, 120s, 240s)
- **Logging**: Parameterised SCM log file path (default: `/var/log/puppetlabs/puppet_data_connector_enhancer_scm.log`)
- **Security**: Fixed file permission race condition - files now created with correct permissions atomically
- **Performance**: Eliminated PuppetDB queries from SCM server class (moved OS detection to client-side facts)
- **README**: Completely rewritten for clarity and conciseness
- **Module Structure**:
  - Renamed `server.pp` to `scm.pp` for clarity
  - Made `scm.pp` and `client.pp` private classes (`@api private`)
  - `script_path` parameter now optional (defaults to `${scm_dir}/puppet_data_connector_enhancer`)

### Fixed

- **Bootstrap Issue**: CSV parser now returns empty hash with warning if file doesn't exist (prevents catalog compilation failure on first run)
- **Resource Conflicts**: Exported resources use unique paths during export, overridden to standard paths during collection
- **Duplicate Declarations**: Removed duplicate `File[$scm_dir]` resource between `init.pp` and `scm.pp`
- **Metadata**: Shortened summary to comply with Puppet Forge 144 character limit
- **Puppet Strings**: Fixed function documentation format warnings
- **Validation**: Added proper lint ignores for parameter lookup and heredoc formatting

### Security

- Changed from root to pe-puppet user for all script execution
- Fixed file creation race condition with atomic permission setting (`File.open` with mode parameter)
- All SCM directories and files owned by pe-puppet with appropriate permissions (0755 for dirs, 0700 for scripts)

## [1.0.0] - 2025-09-24

### Added

- Initial release of puppet_data_connector_enhancer module
- Ruby script for collecting comprehensive Puppet infrastructure metrics
- Automatic dropzone path discovery from puppet_data_connector configuration
- Comprehensive metric collection including:
  - Node management and configuration versions
  - Operating system distribution and details
  - Patch management and security updates
  - CIS compliance scores and scan timestamps
  - Infrastructure Assistant AI token usage (PE 2023.8+)
  - Operational health and error tracking
- Configurable cron job for scheduled metric collection
- Robust error handling with retries and exponential backoff
- Support for both HTTP and HTTPS PuppetDB connections
- Comprehensive parameter validation and type safety
- Full Puppet Strings documentation
- Extensive unit and acceptance test coverage
- Production-ready logging and debugging capabilities

### Features

- **Automatic Configuration Discovery**: Uses lookup() to discover dropzone path from puppet_data_connector
- **Flexible Scheduling**: Configurable cron job with sensible defaults (every 30 minutes)
- **Network Resilience**: HTTP timeout, retry logic, and graceful error handling
- **Security Compliance**: CIS benchmark scores and security patch tracking
- **Infrastructure Assistant Integration**: AI token usage metrics for PE 2023.8+
- **Multi-Protocol Support**: HTTP and HTTPS connections to PuppetDB and Infrastructure Assistant
- **Comprehensive Logging**: Configurable log levels with structured error reporting
- **Parameter Validation**: Strong typing and validation for all configuration parameters

### Technical Details

- **Supported Puppet Versions**: 7.24+ (PE 2021.7+)
- **Supported Operating Systems**: RHEL/CentOS 7-9, Ubuntu 18.04-22.04, Debian 10-12
- **Dependencies**: puppetlabs/stdlib (>= 9.0.0), puppetlabs/cron_core (>= 1.0.0)
- **Ruby Dependencies**: Uses only Ruby standard library (json, net/http, uri, logger, etc.)
- **File Management**: Atomic file writes with proper ownership and permissions
