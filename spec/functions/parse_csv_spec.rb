# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer::parse_csv' do
  let(:csv_content) do
    <<~CSV
      Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score
      node1.example.com,2025-01-01T10:00:00Z,ad hoc,CIS Ubuntu 22.04 Benchmark v1.0.0,Level 1 - Server,85,82
      node2.example.com,2025-01-02T11:30:00Z,scheduled,CIS Red Hat Enterprise Linux 8 Benchmark v2.0.0,Level 2 - Server,92,90
      node3.example.com,2025-01-03T14:45:00Z,ad hoc,CIS Debian Linux 11 Benchmark v1.0.0,Level 1 - Workstation,78,75
    CSV
  end

  context 'when CSV file exists' do
    before do
      allow(File).to receive(:exist?).with('/tmp/test.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/test.csv').and_return(csv_content)
    end

    it 'parses CSV and returns hash of node data' do
      result = subject.execute('/tmp/test.csv')

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly('node1.example.com', 'node2.example.com', 'node3.example.com')
    end

    it 'parses scan timestamp correctly' do
      result = subject.execute('/tmp/test.csv')

      expect(result['node1.example.com']['scan_timestamp']).to eq('2025-01-01T10:00:00Z')
      expect(result['node2.example.com']['scan_timestamp']).to eq('2025-01-02T11:30:00Z')
    end

    it 'parses scan type correctly' do
      result = subject.execute('/tmp/test.csv')

      expect(result['node1.example.com']['scan_type']).to eq('ad hoc')
      expect(result['node2.example.com']['scan_type']).to eq('scheduled')
    end

    it 'parses scanned benchmark correctly' do
      result = subject.execute('/tmp/test.csv')

      expect(result['node1.example.com']['scanned_benchmark']).to eq('CIS Ubuntu 22.04 Benchmark v1.0.0')
      expect(result['node2.example.com']['scanned_benchmark']).to eq('CIS Red Hat Enterprise Linux 8 Benchmark v2.0.0')
      expect(result['node3.example.com']['scanned_benchmark']).to eq('CIS Debian Linux 11 Benchmark v1.0.0')
    end

    it 'parses scanned profile correctly' do
      result = subject.execute('/tmp/test.csv')

      expect(result['node1.example.com']['scanned_profile']).to eq('Level 1 - Server')
      expect(result['node2.example.com']['scanned_profile']).to eq('Level 2 - Server')
      expect(result['node3.example.com']['scanned_profile']).to eq('Level 1 - Workstation')
    end

    it 'parses adjusted compliance score correctly' do
      result = subject.execute('/tmp/test.csv')

      expect(result['node1.example.com']['adjusted_compliance_score']).to eq('85')
      expect(result['node2.example.com']['adjusted_compliance_score']).to eq('92')
      expect(result['node3.example.com']['adjusted_compliance_score']).to eq('78')
    end

    it 'parses exception score correctly' do
      result = subject.execute('/tmp/test.csv')

      expect(result['node1.example.com']['exception_score']).to eq('82')
      expect(result['node2.example.com']['exception_score']).to eq('90')
      expect(result['node3.example.com']['exception_score']).to eq('75')
    end

    it 'lowercases node names for case-insensitive matching' do
      csv_with_uppercase = <<~CSV
        Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score
        NODE1.EXAMPLE.COM,2025-01-01T10:00:00Z,ad hoc,CIS Ubuntu 22.04 Benchmark v1.0.0,Level 1 - Server,85,82
      CSV

      allow(File).to receive(:read).with('/tmp/test.csv').and_return(csv_with_uppercase)

      result = subject.execute('/tmp/test.csv')

      expect(result).to have_key('node1.example.com')
      expect(result).not_to have_key('NODE1.EXAMPLE.COM')
    end
  end

  context 'when CSV file does not exist' do
    before do
      allow(File).to receive(:exist?).with('/tmp/nonexistent.csv').and_return(false)
    end

    it 'returns empty hash' do
      result = subject.execute('/tmp/nonexistent.csv')

      expect(result).to eq({})
    end

    it 'logs warning message' do
      expect(Puppet).to receive(:warning).with('CIS score CSV file does not exist: /tmp/nonexistent.csv')

      subject.execute('/tmp/nonexistent.csv')
    end
  end

  context 'when CSV file is empty' do
    before do
      allow(File).to receive(:exist?).with('/tmp/empty.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/empty.csv').and_return('')
    end

    it 'returns empty hash' do
      result = subject.execute('/tmp/empty.csv')

      expect(result).to eq({})
    end
  end

  context 'when CSV has only headers' do
    before do
      allow(File).to receive(:exist?).with('/tmp/headers.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/headers.csv').and_return("Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score\n")
    end

    it 'returns empty hash' do
      result = subject.execute('/tmp/headers.csv')

      expect(result).to eq({})
    end
  end

  context 'when CSV has malformed data' do
    let(:malformed_csv) do
      <<~CSV
        Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score
        node1.example.com,2025-01-01T10:00:00Z,ad hoc,CIS Ubuntu 22.04 Benchmark v1.0.0,Level 1 - Server,85
      CSV
    end

    before do
      allow(File).to receive(:exist?).with('/tmp/malformed.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/malformed.csv').and_return(malformed_csv)
    end

    it 'handles missing columns gracefully' do
      result = subject.execute('/tmp/malformed.csv')

      expect(result['node1.example.com']['adjusted_compliance_score']).to eq('85')
      expect(result['node1.example.com']['exception_score']).to be_nil
    end
  end

  context 'when CSV has quoted fields with commas' do
    let(:quoted_csv) do
      <<~CSV
        Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score
        node1.example.com,2025-01-01T10:00:00Z,ad hoc,"CIS Ubuntu 22.04 Benchmark v1.0.0, LTS",Level 1 - Server,85,82
      CSV
    end

    before do
      allow(File).to receive(:exist?).with('/tmp/quoted.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/quoted.csv').and_return(quoted_csv)
    end

    it 'parses quoted fields correctly' do
      result = subject.execute('/tmp/quoted.csv')

      expect(result['node1.example.com']['scanned_benchmark']).to eq('CIS Ubuntu 22.04 Benchmark v1.0.0, LTS')
    end
  end

  context 'when CSV has special characters in node names' do
    let(:special_chars_csv) do
      <<~CSV
        Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score
        node-with-dashes.example.com,2025-01-01T10:00:00Z,ad hoc,CIS Ubuntu 22.04 Benchmark v1.0.0,Level 1 - Server,85,82
        node_with_underscores.example.com,2025-01-02T11:30:00Z,scheduled,CIS Red Hat Enterprise Linux 8 Benchmark v2.0.0,Level 2 - Server,92,90
      CSV
    end

    before do
      allow(File).to receive(:exist?).with('/tmp/special.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/special.csv').and_return(special_chars_csv)
    end

    it 'handles node names with dashes and underscores' do
      result = subject.execute('/tmp/special.csv')

      expect(result).to have_key('node-with-dashes.example.com')
      expect(result).to have_key('node_with_underscores.example.com')
    end
  end

  context 'when CSV has duplicate node names' do
    let(:duplicate_csv) do
      <<~CSV
        Node,Scan timestamp,Scan type,Scanned benchmark,Scanned profile,Adjusted compliance score,Exception score
        node1.example.com,2025-01-01T10:00:00Z,ad hoc,CIS Ubuntu 22.04 Benchmark v1.0.0,Level 1 - Server,85,82
        node1.example.com,2025-01-02T11:30:00Z,scheduled,CIS Ubuntu 22.04 Benchmark v1.0.0,Level 1 - Server,90,88
      CSV
    end

    before do
      allow(File).to receive(:exist?).with('/tmp/duplicate.csv').and_return(true)
      allow(File).to receive(:read).with('/tmp/duplicate.csv').and_return(duplicate_csv)
    end

    it 'keeps the last occurrence' do
      result = subject.execute('/tmp/duplicate.csv')

      expect(result['node1.example.com']['scan_timestamp']).to eq('2025-01-02T11:30:00Z')
      expect(result['node1.example.com']['adjusted_compliance_score']).to eq('90')
      expect(result['node1.example.com']['exception_score']).to eq('88')
    end
  end

  context 'parameter validation' do
    it 'requires csv_path parameter' do
      expect { subject.execute }.to raise_error(ArgumentError)
    end

    it 'accepts absolute path' do
      allow(File).to receive(:exist?).with('/opt/puppetlabs/test.csv').and_return(false)

      expect { subject.execute('/opt/puppetlabs/test.csv') }.not_to raise_error
    end
  end
end
