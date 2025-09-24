# Basic usage examples for puppet_data_connector_enhancer

# Example 1: Basic usage with default settings
# This will install the enhancer script and run it every 30 minutes
include puppet_data_connector_enhancer

# Example 2: Custom PuppetDB configuration for distributed architecture
class { 'puppet_data_connector_enhancer':
  puppetdb_host     => 'puppetdb.example.com',
  puppetdb_protocol => 'https',
  puppetdb_port     => 8081,
}

# Example 3: High-frequency collection for dynamic environments
class { 'puppet_data_connector_enhancer':
  cron_minute => '*/15',  # Every 15 minutes
  log_level   => 'DEBUG', # Verbose logging
}

# Example 4: Custom paths and Infrastructure Assistant configuration
class { 'puppet_data_connector_enhancer':
  script_path                => '/opt/puppet/scripts/enhancer.rb',
  dropzone_path              => '/opt/custom/dropzone',
  output_filename            => 'enhanced_metrics.prom',
  infra_assistant_host       => 'infra.example.com',
  infra_assistant_protocol   => 'https',
  http_timeout               => 30,
  http_retries               => 5,
}

# Example 5: Manual execution only (no cron job)
class { 'puppet_data_connector_enhancer':
  cron_ensure => 'absent',
}

# Example 6: Integration with existing puppet_data_connector
class { 'puppet_data_connector':
  dropzone_path => '/opt/puppetlabs/prometheus',
  # ... other puppet_data_connector parameters
}

class { 'puppet_data_connector_enhancer':
  # dropzone_path automatically discovered from puppet_data_connector
  puppetdb_host => $facts['puppet_server'],
  cron_user     => 'prometheus',
}
