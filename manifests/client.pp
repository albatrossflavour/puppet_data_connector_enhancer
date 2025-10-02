# @summary Collect CIS score data for this node from PuppetDB
#
# This class runs on all managed nodes and collects the exported file resource
# containing this node's CIS score data from PuppetDB. The resource is written
# to the OS-appropriate external facts directory where Facter automatically
# loads it as the 'cis_score' structured fact on the next Puppet run.
#
# The fact will contain:
#   - scan_timestamp: ISO 8601 timestamp of the scan
#   - scan_type: Type of scan (e.g., "ad hoc")
#   - scanned_benchmark: CIS benchmark name and version
#   - scanned_profile: Profile applied (e.g., "Level 1 - Server")
#   - adjusted_compliance_score: Score after exceptions
#   - exception_score: Score with exceptions included
#
# @example
#   include puppet_data_connector_enhancer::client
#
class puppet_data_connector_enhancer::client {
  # Collect the exported file resource tagged for this specific node
  # The path and ownership are already set correctly based on this node's OS
  File <<| tag == "cis_score_${trusted['certname']}" |>>
}
