# Parse CIS score CSV file into hash of node data
#
# This function runs on the Puppet master during catalog compilation to parse
# the CIS summary CSV file downloaded from SCM. It returns a hash keyed by
# certname (lowercased) containing each node's CIS score data.
#
# @param csv_path [String] Absolute path to the CSV file on the master
# @return [Hash] Hash of certname => score data, or empty hash on error
#
# @example
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
#
Puppet::Functions.create_function(:'puppet_data_connector_enhancer::parse_csv') do
  dispatch :parse_csv do
    param 'String', :csv_path
  end

  def parse_csv(csv_path)
    unless File.exist?(csv_path)
      Puppet.warning("CIS score CSV not found: #{csv_path}. Skipping CIS score export until SCM export runs. This is expected on first run.")
      return {}
    end

    result = {}

    File.readlines(csv_path).each_with_index do |line, index|
      # Skip header row
      next if index.zero?

      # Skip empty lines
      next if line.strip.empty?

      # Parse CSV line (simple split - data doesn't contain commas or quotes)
      fields = line.strip.split(',')

      # Extract fields based on CSV structure:
      # 0: Scan Timestamp
      # 1: Scan Type
      # 2: Node Name
      # 3: Scanned Benchmark
      # 4: Scanned Profile
      # 5: Adjusted Compliance Score
      # 6: Exception Score

      next if fields.length < 7

      certname = fields[2].strip.downcase
      result[certname] = {
        'scan_timestamp'            => fields[0].strip,
        'scan_type'                 => fields[1].strip,
        'scanned_benchmark'         => fields[3].strip,
        'scanned_profile'           => fields[4].strip,
        'adjusted_compliance_score' => fields[5].strip,
        'exception_score'           => fields[6].strip,
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
