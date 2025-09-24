# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
