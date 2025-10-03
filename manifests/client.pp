# @summary Collect CIS score data for this node from PuppetDB
#
# This private class runs on all managed nodes when SCM collection is enabled.
# It collects the exported file resource containing this node's CIS score data from PuppetDB.
# The resource is written to the OS-appropriate external facts directory where Facter
# automatically loads it as the 'cis_score' structured fact on the next Puppet run.
#
# The fact will contain:
#   - scan_timestamp: ISO 8601 timestamp of the scan
#   - scan_type: Type of scan (e.g., "ad hoc")
#   - scanned_benchmark: CIS benchmark name and version
#   - scanned_profile: Profile applied (e.g., "Level 1 - Server")
#   - adjusted_compliance_score: Score after exceptions
#   - exception_score: Score with exceptions included
#
class puppet_data_connector_enhancer::client {
  # Collect the exported file resource tagged for this specific node
  # Override path and ownership based on this node's OS
  # These resources are exported by puppet_data_connector_enhancer::scm
  File <<| tag == "cis_score_${trusted['certname']}" |>> {
    path  => $facts['os']['family'] ? {
      'windows' => 'C:/ProgramData/PuppetLabs/facter/facts.d/cis_score.yaml',
      default   => '/opt/puppetlabs/facter/facts.d/cis_score.yaml',
    },
    owner => $facts['os']['family'] ? {
      'windows' => undef,
      default   => 'root',
    },
    group => $facts['os']['family'] ? {
      'windows' => undef,
      default   => 'root',
    },
  }
}
