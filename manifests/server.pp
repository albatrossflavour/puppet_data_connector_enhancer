# @summary Export CIS score data from CSV to PuppetDB as exported resources
#
# This class runs only on the PE server. It manages the SCM export script, systemd timer,
# parses the CIS summary CSV file, and exports a file resource for each node to PuppetDB.
# Nodes then collect their specific resource via the client class.
#
# @param scm_dir
#   Base directory for storing SCM scripts and CSV data.
#
# @param scm_host
#   The HTTPS URL of the SCM server.
#
# @param scm_auth
#   The SCM API personal access token for authentication.
#
# @param scm_export_retention
#   Maximum number of API-generated reports to retain on the SCM host.
#
# @param scm_poll_interval
#   Seconds to wait between polling attempts for export completion.
#
# @param scm_max_wait_time
#   Maximum seconds to wait for export completion before timing out.
#
# @param scm_timer_interval
#   The systemd timer interval specification for SCM exports.
#
# @example
#   include puppet_data_connector_enhancer::server
#
class puppet_data_connector_enhancer::server (
  Stdlib::Absolutepath $scm_dir,
  Stdlib::HTTPSUrl $scm_host,
  Sensitive[String[1]] $scm_auth,
  Integer[1] $scm_export_retention,
  Integer[1] $scm_poll_interval,
  Integer[1] $scm_max_wait_time,
  Pattern[/^.+$/] $scm_timer_interval,
) {
  $csv_path = "${scm_dir}/score_data/Summary_Report_API.csv"

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

  # Create systemd timer for SCM export
  systemd::timer { 'puppet-scm-export.timer':
    timer_content => @("EOT"),
      [Unit]
      Description=Run Puppet SCM CIS Score Export

      [Timer]
      OnCalendar=${scm_timer_interval}
      Persistent=true

      [Install]
      WantedBy=timers.target
      | EOT
    service_content => @("EOT"),
      [Unit]
      Description=Puppet SCM CIS Score Export
      After=network.target

      [Service]
      Type=oneshot
      User=root
      Group=root
      ExecStart=${scm_dir}/export_and_download_cis.rb
      WorkingDirectory=${scm_dir}/score_data
      StandardOutput=journal
      StandardError=journal

      [Install]
      WantedBy=multi-user.target
      | EOT
    active  => true,
    enable  => true,
    require => File["${scm_dir}/export_and_download_cis.rb"],
  }

  # Parse the CSV file into a hash of node data
  $cis_data = puppet_data_connector_enhancer::parse_csv($csv_path)

  # Export a file resource for each node
  $cis_data.each |$certname, $data| {
    # Query PuppetDB to determine target node's OS family
    $node_os = puppetdb_query("inventory[facts.os.family] { certname = '${certname}' }")[0]
    $os_family = $node_os ? {
      undef   => 'unknown',
      default => $node_os['facts.os.family'],
    }

    # Set OS-appropriate file attributes
    if $os_family == 'windows' {
      $file_owner = undef
      $file_group = undef
      $file_path = "C:/ProgramData/PuppetLabs/facter/facts.d/cis_score_${certname}.yaml"
    } else {
      $file_owner = 'root'
      $file_group = 'root'
      $file_path = "/opt/puppetlabs/facter/facts.d/cis_score_${certname}.yaml"
    }

    # Each node's exported resource uses certname in path to avoid conflicts during export
    # The collecting node will override the path to the OS-appropriate location
    @@file { "cis_score_fact_${certname}":
      ensure  => file,
      owner   => $file_owner,
      group   => $file_group,
      mode    => '0644',
      path    => $file_path,
      content => epp('puppet_data_connector_enhancer/cis_fact.yaml.epp', {
          'scan_timestamp'            => $data['scan_timestamp'],
          'scan_type'                 => $data['scan_type'],
          'scanned_benchmark'         => $data['scanned_benchmark'],
          'scanned_profile'           => $data['scanned_profile'],
          'adjusted_compliance_score' => $data['adjusted_compliance_score'],
          'exception_score'           => $data['exception_score'],
      }),
      tag     => ["cis_score_${certname}"],
    }
  }
}
