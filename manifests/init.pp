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
#   The full path where the main metrics collection script will be installed.
#   Defaults to ${scm_dir}/puppet_data_connector_enhancer.
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
#   The Security Compliance Management (SCM) server hostname. Used for both Grafana dashboard filters and as the SCM API host when enable_scm_collection is true.
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
# @param scm_timer_interval
#   The systemd timer interval specification for SCM exports (e.g., '*:0/30' for every 30 minutes).
#
# @param scm_log_file
#   The path to the SCM export script log file.
#
# @param custom_queries
#   An array of custom metric definition hashes. Each hash defines a PuppetDB query
#   and its Prometheus metric mapping. See CLAUDE.md for the full YAML field reference.
#
# @param custom_queries_file
#   Override the path to the custom queries YAML config file. Defaults to
#   ${scm_dir}/custom_queries.yaml.
#
# @param enable_orchestrator_metrics
#   Whether to enable collection of PE Orchestrator task and plan metrics.
#   Requires client certificate access to the Orchestrator API on port 8143.
#
# @param orchestrator_jobs_limit
#   Maximum number of recent orchestrator jobs and plans to fetch per collection.
#
# @param enable_classification_metrics
#   Whether to enable collection of node group classification and class usage metrics.
#   Requires client certificate access to the Node Classifier API on port 4433.
#
# @example Basic usage with default parameters
#   include puppet_data_connector_enhancer
#
# @example Enable SCM CIS score collection
#   class { 'puppet_data_connector_enhancer':
#     enable_scm_collection => true,
#     scm_server            => 'scm.example.com',
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
# @example Enable PE Orchestrator task and plan metrics
#   class { 'puppet_data_connector_enhancer':
#     enable_orchestrator_metrics => true,
#     orchestrator_jobs_limit     => 100,
#   }
#
# @example Enable node group classification and class usage metrics
#   class { 'puppet_data_connector_enhancer':
#     enable_classification_metrics => true,
#   }
#
# @example Configure infrastructure servers for Grafana dashboard filters
#   class { 'puppet_data_connector_enhancer':
#     scm_server     => 'gitlab.example.com',
#     grafana_server => 'grafana.example.com',
#     cd4pe_server   => 'cd4pe.example.com',
#   }
#
# @example Custom PuppetDB metrics via YAML-driven queries
#   class { 'puppet_data_connector_enhancer':
#     custom_queries => [
#       {
#         'name'       => 'puppet_custom_nginx_version',
#         'type'       => 'gauge',
#         'help'       => 'Nginx version per node',
#         'endpoint'   => 'fact',
#         'fact_name'  => 'packages',
#         'labels'     => {
#           'node'        => 'certname',
#           'environment' => 'environment',
#           'version'     => 'value.nginx.version',
#         },
#         'value_field' => undef,
#         'filter'      => undef,
#       },
#     ],
#   }
#
class puppet_data_connector_enhancer (
  Enum['present', 'absent'] $ensure                     = 'present',
  Optional[Stdlib::Absolutepath] $script_path           = undef,
  Integer[1, 300] $http_timeout                         = 5,
  Integer[1, 10] $http_retries                          = 3,
  Numeric $retry_delay                                  = 2.0,
  Enum['DEBUG', 'INFO', 'WARN', 'ERROR'] $log_level     = 'INFO',
  Enum['present', 'absent'] $timer_ensure               = 'present',
  String[1] $timer_interval                             = '*:0/30',
  Stdlib::Absolutepath $dropzone                        = lookup('puppet_data_connector::dropzone', Stdlib::Absolutepath, 'first', '/opt/puppetlabs/puppet/prometheus_dropzone'), # lint:ignore:lookup_in_parameter
  String[1] $output_filename                            = 'puppet_enhanced_metrics.prom',
  Optional[Stdlib::Fqdn] $puppet_server                 = $facts['puppet_server'],
  Optional[Stdlib::Fqdn] $scm_server                    = undef,
  Optional[Stdlib::Fqdn] $grafana_server                = undef,
  Optional[Stdlib::Fqdn] $cd4pe_server                  = undef,
  Boolean $enable_scm_collection                        = false,
  Optional[Sensitive[String[1]]] $scm_auth              = undef,
  Stdlib::Absolutepath $scm_dir                         = '/opt/puppetlabs/puppet_data_connector_enhancer',
  Integer[1] $scm_export_retention                      = 8,
  Integer[1] $scm_poll_interval                         = 30,
  Integer[1] $scm_max_wait_time                         = 900,
  Pattern[/^.+$/] $scm_timer_interval                   = '*:0/30',
  Stdlib::Absolutepath $scm_log_file                    = '/var/log/puppetlabs/puppet_data_connector_enhancer_scm.log',
  Optional[Array] $custom_queries                       = undef,
  Optional[Stdlib::Absolutepath] $custom_queries_file   = undef,
  Integer[0] $custom_queries_row_limit                  = 500,
  Boolean $enable_orchestrator_metrics                  = false,
  Integer[1, 200] $orchestrator_jobs_limit              = 50,
  Boolean $enable_classification_metrics                = false,
) {
  $dropzone_file = "${dropzone}/${output_filename}"

  # Set script path - defaults to scm_dir location
  $_script_path = pick($script_path, "${scm_dir}/puppet_data_connector_enhancer")

  # Set custom queries file path
  $_custom_queries_file = pick($custom_queries_file, "${scm_dir}/custom_queries.yaml")

  # Validate SCM configuration if enabled
  if $enable_scm_collection {
    if !$scm_server or !$scm_auth {
      fail('enable_scm_collection is true but scm_server and/or scm_auth are not configured')
    }
  }

  # Build SCM host URL from scm_server
  $scm_host = $scm_server ? {
    undef   => undef,
    default => "https://${scm_server}",
  }

  # SCM CIS Score Collection (server-side only)
  if $enable_scm_collection and $facts['puppet_server'] == $facts['clientcert'] {
    # Include SCM class - contains all SCM export logic and fact resource exports
    class { 'puppet_data_connector_enhancer::scm':
      scm_dir              => $scm_dir,
      scm_host             => $scm_host,
      scm_auth             => $scm_auth,
      scm_export_retention => $scm_export_retention,
      scm_poll_interval    => $scm_poll_interval,
      scm_max_wait_time    => $scm_max_wait_time,
      scm_timer_interval   => $scm_timer_interval,
      scm_log_file         => $scm_log_file,
    }
  }

  # All nodes collect their CIS score facts (if SCM collection is enabled)
  if $enable_scm_collection {
    include puppet_data_connector_enhancer::client
  }

  # Create scm_dir for scripts
  file { $scm_dir:
    ensure => 'directory',
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0755',
  }

  # Manage custom queries YAML config file
  if $custom_queries {
    file { $_custom_queries_file:
      ensure  => 'file',
      content => epp('puppet_data_connector_enhancer/custom_queries.yaml.epp', {
          'metrics' => $custom_queries,
      }),
      mode    => '0644',
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      require => File[$scm_dir],
    }
  } else {
    file { $_custom_queries_file:
      ensure => 'absent',
    }
  }

  # Install the main metrics collection script
  file { $_script_path:
    ensure  => $ensure,
    content => epp('puppet_data_connector_enhancer/puppet_data_connector_enhancer.epp', {
        'http_timeout'        => $http_timeout,
        'http_retries'        => $http_retries,
        'retry_delay'         => $retry_delay,
        'log_level'           => $log_level,
        'dropzone_file'       => $dropzone_file,
        'puppet_server'       => pick_default($puppet_server, ''),
        'scm_server'          => pick_default($scm_server, ''),
        'grafana_server'      => pick_default($grafana_server, ''),
        'cd4pe_server'        => pick_default($cd4pe_server, ''),
        'scm_dir'             => $scm_dir,
        'custom_queries_file'          => $_custom_queries_file,
        'custom_queries_row_limit'     => $custom_queries_row_limit,
        'enable_orchestrator_metrics'  => $enable_orchestrator_metrics,
        'orchestrator_jobs_limit'      => $orchestrator_jobs_limit,
        'enable_classification_metrics' => $enable_classification_metrics,
    }),
    mode    => '0755',
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    require => [Class['puppet_data_connector'], File[$scm_dir], File[$_custom_queries_file]],
  }

  # Create systemd service and timer for scheduled execution
  if $ensure == 'present' and $timer_ensure == 'present' {
    systemd::unit_file { 'puppet-data-connector-enhancer.service':
      content => epp('puppet_data_connector_enhancer/puppet-data-connector-enhancer.service.epp', {
          'script_path'   => $_script_path,
          'dropzone_file' => $dropzone_file,
      }),
      require => File[$_script_path],
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
