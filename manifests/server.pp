# @summary Export CIS score data from CSV to PuppetDB as exported resources
#
# This class runs only on the PE server during catalog compilation. It parses the
# CIS summary CSV file (downloaded by the SCM export script) and exports a file resource for
# each node to PuppetDB. Nodes then collect their specific resource via the client class.
#
# @param csv_path
#   Absolute path to the CSV file containing CIS scores for all nodes.
#   The file must be readable by the pe-puppet user (mode 0644).
#
# @example
#   include puppet_data_connector_enhancer::server
#
class puppet_data_connector_enhancer::server (
  Stdlib::Absolutepath $csv_path = "${puppet_data_connector_enhancer::scm_dir}/score_data/Summary_Report_API.csv",
) {
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
