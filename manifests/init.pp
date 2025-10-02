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
# @param dropzone
#   The path to the dropzone directory. Defaults to the puppet_data_connector configuration.
#
# @param output_filename
#   The filename for the metrics output (will be placed in the dropzone).
#
# @param puppet_server
#   The Puppet Server hostname (for Grafana dashboard filters).
#
# @param scm_server
#   The Source Control Management (SCM) server hostname (for Grafana dashboard filters).
#
# @param grafana_server
#   The Grafana server hostname (for Grafana dashboard filters).
#
# @param cd4pe_server
#   The Continuous Delivery for PE (CD4PE) server hostname (for Grafana dashboard filters).
#
# @param enable_scm_collection
#   Whether to enable SCM CIS score collection and export functionality.
#
# @param scm_host
#   The HTTPS URL of the Security Compliance Management (SCM) server (required if enable_scm_collection is true).
#
# @param scm_auth
#   The SCM API personal access token for authentication. Should not include 'Bearer' prefix (required if enable_scm_collection is true).
#
# @param scm_dir
#   Base directory for storing SCM scripts and CSV data. Must be an absolute path.
#
# @param scm_export_retention
#   Maximum number of API-generated reports to retain on the SCM host. Must be >= 1.
#
# @param scm_poll_interval
#   Seconds to wait between polling attempts for export completion. Must be >= 1.
#
# @param scm_max_wait_time
#   Maximum seconds to wait for export completion before timing out. Must be >= 1.
#
# @example Basic usage with default parameters
#   include puppet_data_connector_enhancer
#
# @example Enable SCM CIS score collection
#   class { 'puppet_data_connector_enhancer':
#     enable_scm_collection => true,
#     scm_host              => 'https://scm.example.com',
#     scm_auth              => Sensitive(lookup('scm_api_token')),
#   }
#
# @example Custom timeouts and debugging
#   class { 'puppet_data_connector_enhancer':
#     http_timeout => 30,
#     log_level    => 'DEBUG',
#   }
#
# @example Run every 15 minutes instead of default 30
#   class { 'puppet_data_connector_enhancer':
#     timer_interval => '*:0/15',
#   }
#
# @example Configure infrastructure servers for Grafana dashboard filters
#   class { 'puppet_data_connector_enhancer':
#     scm_server     => 'gitlab.example.com',
#     grafana_server => 'grafana.example.com',
#     cd4pe_server   => 'cd4pe.example.com',
#   }
#
class puppet_data_connector_enhancer (
  Enum['present', 'absent'] $ensure                     = 'present',
  Stdlib::Absolutepath $script_path                     = '/usr/local/bin/puppet_data_connector_enhancer',
  Integer[1, 300] $http_timeout                         = 5,
  Integer[1, 10] $http_retries                          = 3,
  Numeric $retry_delay                                  = 2.0,
  Enum['DEBUG', 'INFO', 'WARN', 'ERROR'] $log_level     = 'INFO',
  Enum['present', 'absent'] $timer_ensure               = 'present',
  String[1] $timer_interval                             = '*:0/30',
  Stdlib::Absolutepath $dropzone                        = lookup('puppet_data_connector::dropzone', Stdlib::Absolutepath, 'first', '/opt/puppetlabs/puppet/prometheus_dropzone'),
  String[1] $output_filename                            = 'puppet_enhanced_metrics.prom',
  Optional[Stdlib::Fqdn] $puppet_server                 = $facts['puppet_server'],
  Optional[Stdlib::Fqdn] $scm_server                    = undef,
  Optional[Stdlib::Fqdn] $grafana_server                = undef,
  Optional[Stdlib::Fqdn] $cd4pe_server                  = undef,
  Boolean $enable_scm_collection                        = false,
  Optional[Stdlib::HTTPSUrl] $scm_host                  = undef,
  Optional[Sensitive[String[1]]] $scm_auth              = undef,
  Stdlib::Absolutepath $scm_dir                         = '/opt/puppetlabs/puppet_data_connector_enhancer',
  Integer[1] $scm_export_retention                      = 8,
  Integer[1] $scm_poll_interval                         = 30,
  Integer[1] $scm_max_wait_time                         = 900,
) {

  $dropzone_file = "${dropzone}/${output_filename}"

  # Validate SCM configuration if enabled
  if $enable_scm_collection {
    if !$scm_host or !$scm_auth {
      fail('enable_scm_collection is true but scm_host and/or scm_auth are not configured')
    }
  }

  # SCM CIS Score Collection (server-side only)
  if $enable_scm_collection and $facts['puppet_server'] == $facts['clientcert'] {
    # Create SCM directories
    file { $scm_dir:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    file { "${scm_dir}/score_data":
      ensure  => 'directory',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => File[$scm_dir],
    }

    # Deploy SCM export and download script
    file { "${scm_dir}/export_and_download_cis.rb":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => epp('puppet_data_connector_enhancer/export_and_download_cis.rb.epp', {
          'scm_host'         => $scm_host,
          'auth'             => $scm_auth,
          'export_retention' => $scm_export_retention,
          'poll_interval'    => $scm_poll_interval,
          'max_wait_time'    => $scm_max_wait_time,
      }),
      require => File[$scm_dir],
    }

    # Include server class to export CIS fact resources
    include puppet_data_connector_enhancer::server
  }

  # All nodes collect their CIS score facts (if SCM collection is enabled)
  if $enable_scm_collection {
    include puppet_data_connector_enhancer::client
  }

  # Install the Ruby script
  file { $script_path:
    ensure  => $ensure,
    content => epp('puppet_data_connector_enhancer/puppet_data_connector_enhancer.epp', {
      'http_timeout'   => $http_timeout,
      'http_retries'   => $http_retries,
      'retry_delay'    => $retry_delay,
      'log_level'      => $log_level,
      'dropzone_file'  => $dropzone_file,
      'puppet_server'  => pick($puppet_server, ''),
      'scm_server'     => pick($scm_server, ''),
      'grafana_server' => pick($grafana_server, ''),
      'cd4pe_server'   => pick($cd4pe_server, ''),
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
        'script_path'   => $script_path,
        'dropzone_file' => $dropzone_file,
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
