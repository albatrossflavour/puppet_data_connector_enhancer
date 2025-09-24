# puppet_data_connector_enhancer

[![Puppet Forge](https://img.shields.io/puppetforge/v/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Puppet Forge - endorsement](https://img.shields.io/puppetforge/e/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/albatrossflavour/puppet_data_connector_enhancer.svg)](https://forge.puppet.com/modules/albatrossflavour/puppet_data_connector_enhancer)
[![Apache-2 License](https://img.shields.io/github/license/albatrossflavour/puppet-puppet_data_connector_enhancer.svg)](LICENSE)

## Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with puppet_data_connector_enhancer](#setup)
   - [What puppet_data_connector_enhancer affects](#what-puppet_data_connector_enhancer-affects)
   - [Setup requirements](#setup-requirements)
   - [Beginning with puppet_data_connector_enhancer](#beginning-with-puppet_data_connector_enhancer)
3. [Usage - Configuration options and additional functionality](#usage)
   - [Basic usage](#basic-usage)
   - [Advanced configuration](#advanced-configuration)
   - [Integration with puppet_data_connector](#integration-with-puppet_data_connector)
4. [Reference](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
7. [Support](#support)

## Description

The `puppet_data_connector_enhancer` module extends the functionality of Puppet's premium `puppet_data_connector` module by deploying and managing a Ruby script that collects comprehensive Puppet infrastructure metrics and delivers them to the data connector dropzone.

This module enhances your Puppet monitoring capabilities by providing detailed metrics about:

- **Node Management**: Configuration versions, environment distribution, and operating system details
- **Patch Management**: Available updates, security patches, patch groups, and compliance status
- **Security Compliance**: CIS benchmark scores and scan timestamps
- **Infrastructure Assistant**: AI token usage and performance metrics (PE 2023.8+)
- **Operational Health**: Collection timing, success rates, and error tracking

The module automatically discovers the dropzone configuration from your existing `puppet_data_connector` setup, ensuring consistent configuration management without duplication.

## Setup

### What puppet_data_connector_enhancer affects

This module manages the following components:

- **Ruby script**: Installs `/usr/local/bin/puppet_data_connector_enhancer.rb` (configurable path)
- **Cron job**: Schedules regular metric collection (default: every 30 minutes)
- **Metrics files**: Writes Prometheus-format metrics to the data connector dropzone
- **Network connections**: Makes HTTP/HTTPS requests to PuppetDB and Infrastructure Assistant APIs

The module does **not** affect:

- Existing `puppet_data_connector` configuration
- PuppetDB or Infrastructure Assistant services
- System packages or dependencies (uses Ruby standard library only)

### Setup requirements

**Prerequisites:**

- Puppet Enterprise or Puppet Platform (Puppet 7.24+)
- The premium `puppet_data_connector` module must be installed and configured
- Access to PuppetDB API (typically port 8080/8081)
- Access to Infrastructure Assistant API (typically port 8145) - optional
- Network connectivity from the node running this module to PuppetDB

**Dependencies:**

This module depends on:

- `puppetlabs/stdlib` (>= 9.0.0 < 10.0.0)
- `puppet/systemd` (>= 4.0.0 < 8.0.0)

### Beginning with puppet_data_connector_enhancer

The simplest way to get started is to include the class with default parameters:

```puppet
include puppet_data_connector_enhancer
```

This will:

1. Install the metrics collection script to `/usr/local/bin/puppet_data_connector_enhancer.rb`
2. Create a systemd timer running every 30 minutes as the `pe-puppet` user
3. Automatically discover the dropzone path from your `puppet_data_connector` configuration
4. Connect to PuppetDB on `localhost:8080` using HTTP

## Usage

### Basic usage

**Default configuration** (recommended for most installations):

```puppet
include puppet_data_connector_enhancer
```

**Custom timeouts and debugging**:

```puppet
class { 'puppet_data_connector_enhancer':
  http_timeout => 30,
  log_level    => 'DEBUG',
}
```

**Increased collection frequency** (for high-change environments):

```puppet
class { 'puppet_data_connector_enhancer':
  timer_interval => '*:0/15',  # Every 15 minutes
}
```

### Advanced configuration

**Custom timeouts and retry behavior**:

```puppet
class { 'puppet_data_connector_enhancer':
  http_timeout    => 30,
  http_retries    => 5,
  retry_delay     => 3.0,
  log_level       => 'DEBUG',
}
```

**Custom installation paths and scheduling**:

```puppet
class { 'puppet_data_connector_enhancer':
  script_path      => '/opt/puppet/scripts/enhancer.rb',
  dropzone         => '/opt/custom/dropzone',
  output_filename  => 'enhanced_puppet_metrics.prom',
  timer_interval   => '01,31:00',  # Run at 1 and 31 minutes past each hour
}
```

**Disable automatic execution** (manual operation only):

```puppet
class { 'puppet_data_connector_enhancer':
  timer_ensure => 'absent',
}
```

### Integration with puppet_data_connector

This module is designed to work seamlessly with the premium `puppet_data_connector` module:

```puppet
# Configure the base data connector
class { 'puppet_data_connector':
  dropzone => '/opt/puppetlabs/prometheus',
  # ... other puppet_data_connector parameters
}

# Add enhanced metrics collection
class { 'puppet_data_connector_enhancer':
  # dropzone automatically discovered from puppet_data_connector
  puppetdb_host => $facts['puppet_server'],
}
```

The enhancer automatically discovers the dropzone path using:

```puppet
lookup('puppet_data_connector::dropzone', Stdlib::Absolutepath, 'first', '/opt/puppetlabs/puppet/prometheus_dropzone')
```

## Reference

This module is documented using Puppet Strings. For detailed parameter information, see the generated [REFERENCE.md](REFERENCE.md) or run:

```bash
puppet strings generate --format markdown
```

### Key parameters

| Parameter           | Type                                   | Default                             | Description                              |
| ------------------- | -------------------------------------- | ----------------------------------- | ---------------------------------------- |
| `ensure`            | Enum['present', 'absent']              | `'present'`                         | Whether the enhancer should be installed |
| `puppetdb_host`     | Stdlib::Host                           | `'localhost'`                       | PuppetDB hostname                        |
| `puppetdb_protocol` | Enum['http', 'https']                  | `'http'`                            | PuppetDB connection protocol             |
| `dropzone`          | Stdlib::Absolutepath                   | Lookup from `puppet_data_connector` | Directory for metrics files              |
| `timer_interval`    | String                                 | `'*:0/30'`                          | Systemd timer interval specification     |
| `service_user`      | String                                 | `'pe-puppet'`                       | User for systemd service                 |
| `log_level`         | Enum['DEBUG', 'INFO', 'WARN', 'ERROR'] | `'INFO'`                            | Logging verbosity                        |

### Supported metrics

The enhancer collects 17 different metric types:

- `puppet_configuration_version` - Configuration version per node
- `puppet_node_count` - Node counts by environment
- `puppet_state_overview` - PuppetDB state statistics
- `puppet_node_os` - Operating system details per node
- `puppet_patching_data` - Package update counts and details
- `puppet_cis_data` - CIS compliance scores
- `puppet_infra_assistant_tokens_total` - AI token usage metrics
- And more...

Full metric documentation is available in the script's help output:

```bash
/usr/local/bin/puppet_data_connector_enhancer.rb --help
```

## Limitations

### Operating system support

This module supports the same operating systems as Puppet Enterprise:

- **Red Hat family**: RHEL 7-9, CentOS 7-9, Rocky Linux 8+, AlmaLinux 8+
- **Debian family**: Debian 10-12, Ubuntu 18.04-22.04
- **SUSE family**: SLES 12-15

### Known limitations

- **Puppet Enterprise dependency**: Requires PE-compatible Ruby environment
- **Network access**: Requires connectivity to PuppetDB and optionally Infrastructure Assistant
- **Privilege requirements**: Systemd service runs as `pe-puppet` user by default
- **SSL verification**: Disabled by default for self-signed certificates (common in PE)

### Version compatibility

| Module Version | Puppet Version | PE Version |
| -------------- | -------------- | ---------- |
| 1.x            | 7.24+          | 2021.7+    |

### Infrastructure Assistant metrics

Infrastructure Assistant metrics require Puppet Enterprise 2023.8 or later. The module gracefully handles older PE versions by collecting other metrics and logging connection failures.

## Development

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`pdk test unit` and `pdk test acceptance`)
5. Run static analysis (`pdk validate`)
6. Submit a pull request

### Testing

This module includes comprehensive test coverage:

```bash
# Unit tests
pdk test unit

# Acceptance tests (requires test infrastructure)
pdk test acceptance

# All tests and validation
pdk test
```

### Code standards

This module follows:

- [Puppet Development Kit (PDK)](https://puppet.com/docs/pdk/) standards
- [Puppet code style guide](https://puppet.com/docs/puppet/latest/style_guide.html)
- [Puppet Strings documentation](https://puppet.com/docs/puppet/latest/puppet_strings.html) format

## Support

### Community support

- **GitHub Issues**: [Report bugs and request features](https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer/issues)
- **Pull Requests**: [Contribute improvements](https://github.com/albatrossflavour/puppet-puppet_data_connector_enhancer/pulls)

### Professional services

For enterprise support, training, and consulting services, please contact the module author.

### Troubleshooting

**Common issues:**

1. **Permission denied errors**: Ensure the `pe-puppet` user has access to the dropzone directory
2. **Connection refused**: Verify PuppetDB connectivity and firewall settings
3. **SSL certificate errors**: Expected with self-signed certificates; verification is disabled by default
4. **Missing metrics**: Check systemd service logs and script output with `--verbose` flag

**Debug mode:**

```bash
# Run manually with debug logging
/usr/local/bin/puppet_data_connector_enhancer.rb --verbose --output /tmp/debug_metrics.prom

# Check systemd service logs
journalctl -u puppet-data-connector-enhancer.service
journalctl -u puppet-data-connector-enhancer.timer
```

---

Copyright 2024 albatrossflavour

Licensed under the Apache License, Version 2.0
