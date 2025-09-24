# @summary Manages the Puppet Data Connector Enhancer
#
# This class manages the installation and configuration of a Ruby script that
# enhances the puppet_data_connector module by collecting additional Puppet
# infrastructure metrics and pushing them to the data connector dropzone.
#
# The module discovers the dropzone path from the existing puppet_data_connector
# configuration to avoid configuration duplication.
#
# @param ensure
#   Whether the data connector enhancer should be present or absent.
#
# @param script_path
#   The full path where the Ruby script will be installed.
#
# @param puppetdb_host
#   The hostname of the PuppetDB server to query.
#
# @param puppetdb_port
#   The port number for PuppetDB connections.
#
# @param puppetdb_protocol
#   The protocol to use for PuppetDB connections (http or https).
#
# @param infra_assistant_host
#   The hostname of the Infrastructure Assistant server.
#
# @param infra_assistant_port
#   The port number for Infrastructure Assistant connections.
#
# @param infra_assistant_protocol
#   The protocol to use for Infrastructure Assistant connections.
#
# @param http_timeout
#   HTTP request timeout in seconds.
#
# @param http_retries
#   Number of retry attempts for failed HTTP requests.
#
# @param retry_delay
#   Initial delay between retry attempts in seconds.
#
# @param log_level
#   The logging level for the script (DEBUG, INFO, WARN, ERROR).
#
# @param timer_ensure
#   Whether the systemd timer should be present or absent.
#
# @param timer_interval
#   The systemd timer interval specification (e.g., '*:0/30' for every 30 minutes).
#
# @param service_user
#   The user under which the service should run.
#
# @param dropzone
#   The path to the dropzone directory. Defaults to the puppet_data_connector configuration.
#
# @param output_filename
#   The filename for the metrics output (will be placed in the dropzone).
#
# @example Basic usage with default parameters
#   include puppet_data_connector_enhancer
#
# @example Custom configuration for HTTPS PuppetDB
#   class { 'puppet_data_connector_enhancer':
#     puppetdb_host     => 'puppet.example.com',
#     puppetdb_protocol => 'https',
#   }
#
# @example Run every 15 minutes instead of default 30
#   class { 'puppet_data_connector_enhancer':
#     timer_interval => '*:0/15',
#   }
#
class puppet_data_connector_enhancer (
  Enum['present', 'absent'] $ensure                     = 'present',
  Stdlib::Absolutepath $script_path                     = '/usr/local/bin/puppet_data_connector_enhancer.rb',
  Stdlib::Host $puppetdb_host                           = 'localhost',
  Stdlib::Port $puppetdb_port                           = 8080,
  Enum['http', 'https'] $puppetdb_protocol              = 'http',
  Stdlib::Host $infra_assistant_host                    = 'localhost',
  Stdlib::Port $infra_assistant_port                    = 8145,
  Enum['http', 'https'] $infra_assistant_protocol       = 'https',
  Integer[1, 300] $http_timeout                         = 5,
  Integer[1, 10] $http_retries                          = 3,
  Numeric $retry_delay                                  = 2.0,
  Enum['DEBUG', 'INFO', 'WARN', 'ERROR'] $log_level     = 'INFO',
  Enum['present', 'absent'] $timer_ensure               = 'present',
  String[1] $timer_interval                             = '*:0/30',
  String[1] $service_user                               = 'pe-puppet',
  Stdlib::Absolutepath $dropzone                        = lookup('puppet_data_connector::dropzone', Stdlib::Absolutepath, 'first', '/opt/puppetlabs/puppet/prometheus_dropzone'),
  String[1] $output_filename                            = 'puppet_enhanced_metrics.prom',
) {

  $dropzone_file = "${dropzone}/${output_filename}"

  # Install the Ruby script
  file { $script_path:
    ensure  => $ensure,
    content => epp('puppet_data_connector_enhancer/puppet_data_connector_enhancer.rb.epp', {
      'puppetdb_host'               => $puppetdb_host,
      'puppetdb_port'               => $puppetdb_port,
      'puppetdb_protocol'           => $puppetdb_protocol,
      'infra_assistant_host'        => $infra_assistant_host,
      'infra_assistant_port'        => $infra_assistant_port,
      'infra_assistant_protocol'    => $infra_assistant_protocol,
      'http_timeout'                => $http_timeout,
      'http_retries'                => $http_retries,
      'retry_delay'                 => $retry_delay,
      'log_level'                   => $log_level,
      'dropzone_file'               => $dropzone_file,
    }),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => Class['puppet_data_connector'],
  }

  # Create systemd service and timer for scheduled execution
  if $ensure == 'present' and $timer_ensure == 'present' {
    systemd::unit_file { 'puppet-data-connector-enhancer.service':
      content => epp('puppet_data_connector_enhancer/puppet-data-connector-enhancer.service.epp', {
        'script_path' => $script_path,
        'dropzone_file' => $dropzone_file,
        'service_user' => $service_user,
      }),
      require => File[$script_path],
    }

    systemd::unit_file { 'puppet-data-connector-enhancer.timer':
      content => epp('puppet_data_connector_enhancer/puppet-data-connector-enhancer.timer.epp', {
        'timer_interval' => $timer_interval,
      }),
      require => Systemd::Unit_file['puppet-data-connector-enhancer.service'],
    }

    service { 'puppet-data-connector-enhancer.timer':
      ensure  => 'running',
      enable  => true,
      require => Systemd::Unit_file['puppet-data-connector-enhancer.timer'],
    }
  } elsif $ensure == 'absent' or $timer_ensure == 'absent' {
    service { 'puppet-data-connector-enhancer.timer':
      ensure => 'stopped',
      enable => false,
    }

    systemd::unit_file { ['puppet-data-connector-enhancer.service', 'puppet-data-connector-enhancer.timer']:
      ensure => 'absent',
    }
  }
}
