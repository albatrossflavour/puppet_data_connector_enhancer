require 'csv'

# Parse CIS score CSV file into hash of node data.
#
# This function runs on the Puppet master during catalog compilation to parse
# the CIS summary CSV file downloaded from SCM. It returns a hash keyed by
# certname (lowercased) containing each node's CIS score data.
#
# @example Parse CSV file
#   $scores = puppet_data_connector_enhancer::parse_csv('/opt/puppetlabs/puppet_data_connector_enhancer/score_data/Summary_Report_API.csv')
#   # => {
#   #      'node1.example.com' => {
#   #        'scan_timestamp' => '2025-09-09T00:17:43Z',
#   #        'scan_type' => 'ad hoc',
#   #        'scanned_benchmark' => '2.0.0 CIS Ubuntu Linux 22.04 LTS',
#   #        'scanned_profile' => 'Level 1 - Server',
#   #        'adjusted_compliance_score' => '84',
#   #        'exception_score' => '84'
#   #      }
#   #    }
Puppet::Functions.create_function(:'puppet_data_connector_enhancer::parse_csv') do
  # @param csv_path Absolute path to the CSV file on the master
  # @return Hash of certname => score data, or empty hash if file doesn't exist
  dispatch :parse_csv do
    param 'String', :csv_path
  end

  def parse_csv(csv_path)
    unless File.exist?(csv_path)
      Puppet.warning("CIS score CSV not found: #{csv_path}. Skipping CIS score export until SCM export runs. This is expected on first run.")
      return {}
    end

    result = {}

    CSV.foreach(csv_path, headers: true, skip_blanks: true) do |row|
      # Extract fields based on CSV headers:
      # Scan Timestamp, Scan Type, Node Name, Scanned Benchmark, Scanned Profile,
      # Adjusted Compliance Score, Exception Score

      # Skip rows with insufficient data
      next unless row['Node Name'] && row['Scan Timestamp']

      certname = row['Node Name'].strip.downcase
      result[certname] = {
        'scan_timestamp'            => row['Scan Timestamp'].to_s.strip,
        'scan_type'                 => row['Scan Type'].to_s.strip,
        'scanned_benchmark'         => row['Scanned Benchmark'].to_s.strip,
        'scanned_profile'           => row['Scanned Profile'].to_s.strip,
        'adjusted_compliance_score' => row['Adjusted Compliance Score'].to_s.strip,
        'exception_score'           => row['Exception Score'].to_s.strip,
      }
    end

    # Warn if CSV exists but contains no data (different from file not existing)
    if result.empty?
      Puppet.warning("CIS score CSV #{csv_path} exists but contains no valid node data. Check CSV format and contents.")
    end

    result
  rescue Puppet::ParseError
    # Re-raise ParseError to fail catalog compilation
    raise
  rescue StandardError => e
    # Any other error during parsing should also fail compilation
    raise Puppet::ParseError, "Error parsing CIS CSV #{csv_path}: #{e.message}\nBacktrace: #{e.backtrace.first(5).join("\n")}"
  end
end
