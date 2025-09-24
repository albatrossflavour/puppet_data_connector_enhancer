# Basic usage examples for puppet_data_connector_enhancer

# Example 1: Basic usage with default settings
# This will install the enhancer script and run it every 30 minutes
include puppet_data_connector_enhancer

# Example 2: Custom timeouts and debugging
class { 'puppet_data_connector_enhancer':
  http_timeout => 30,
  log_level    => 'DEBUG',
}

# Example 3: High-frequency collection for dynamic environments
class { 'puppet_data_connector_enhancer':
  timer_interval => '*:0/15',  # Every 15 minutes
  log_level      => 'DEBUG',   # Verbose logging
}

# Example 4: Custom paths and timeouts
class { 'puppet_data_connector_enhancer':
  script_path     => '/opt/puppet/scripts/enhancer.rb',
  dropzone        => '/opt/custom/dropzone',
  output_filename => 'enhanced_metrics.prom',
  http_timeout    => 30,
  http_retries    => 5,
}

# Example 5: Manual execution only (no systemd timer)
class { 'puppet_data_connector_enhancer':
  timer_ensure => 'absent',
}

# Example 6: Integration with existing puppet_data_connector
class { 'puppet_data_connector':
  dropzone => '/opt/puppetlabs/prometheus',
  # ... other puppet_data_connector parameters
}

class { 'puppet_data_connector_enhancer':
  # dropzone automatically discovered from puppet_data_connector
  # Uses default PE server configuration (localhost:8081, HTTPS)
}
