# @summary Manage SCM CIS score collection and distribution
#
# This private class runs only on the PE server when SCM collection is enabled.
# It manages the SCM export script, systemd timer, parses the CIS summary CSV file,
# and exports a file resource for each node to PuppetDB.
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
# @param scm_log_file
#   The path to the SCM export script log file.
#
class puppet_data_connector_enhancer::scm (
  Stdlib::Absolutepath $scm_dir,
  Stdlib::HTTPSUrl $scm_host,
  Sensitive[String[1]] $scm_auth,
  Integer[1] $scm_export_retention,
  Integer[1] $scm_poll_interval,
  Integer[1] $scm_max_wait_time,
  Pattern[/^.+$/] $scm_timer_interval,
  Stdlib::Absolutepath $scm_log_file,
) {
  $csv_path = "${scm_dir}/score_data/Summary_Report_API.csv"

  # Create score_data subdirectory (scm_dir is created by init.pp)
  file { "${scm_dir}/score_data":
    ensure => 'directory',
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0755',
  }

  # Deploy SCM export and download script
  file { "${scm_dir}/export_and_download_cis":
    ensure  => file,
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    mode    => '0700',
    content => epp('puppet_data_connector_enhancer/export_and_download_cis.rb.epp', {
        'scm_host'         => $scm_host,
        'auth'             => $scm_auth,
        'export_retention' => $scm_export_retention,
        'poll_interval'    => $scm_poll_interval,
        'max_wait_time'    => $scm_max_wait_time,
        'scm_dir'          => $scm_dir,
        'scm_log_file'     => $scm_log_file,
    }),
    require => File["${scm_dir}/score_data"],
  }

  # Create systemd timer for SCM export
  systemd::timer { 'puppet-scm-export.timer':
    timer_content   => @("EOT"),
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
      User=pe-puppet
      Group=pe-puppet
      ExecStart=${scm_dir}/export_and_download_cis
      WorkingDirectory=${scm_dir}/score_data
      StandardOutput=journal
      StandardError=journal

      [Install]
      WantedBy=multi-user.target
    | EOT
    active          => true,
    enable          => true,
    require         => File["${scm_dir}/export_and_download_cis"],
  }

  # Parse the CSV file into a hash of node data
  $cis_data = puppet_data_connector_enhancer::parse_csv($csv_path)

  # Export a file resource for each node
  # Each resource has a unique path during export to avoid conflicts
  # OS-specific paths and ownership are overridden by the client when collecting
  $cis_data.each |$certname, $data| {
    @@file { "cis_score_fact_${certname}":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      path    => "/opt/puppetlabs/facter/facts.d/cis_score_${certname}.yaml",
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
