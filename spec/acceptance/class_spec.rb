# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'puppet_data_connector_enhancer class' do
  context 'with default parameters' do
    let(:pp) do
      <<-MANIFEST
        class { 'puppet_data_connector_enhancer': }
      MANIFEST
    end

    it 'applies idempotently' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/usr/local/bin/puppet_data_connector_enhancer.rb') do
      it { is_expected.to exist }
      it { is_expected.to be_file }
      it { is_expected.to be_mode 755 }
      it { is_expected.to be_owned_by 'root' }
      it { is_expected.to be_grouped_into 'root' }
      it { is_expected.to be_executable }

      its(:content) do
        is_expected.to match(%r{#!/opt/puppetlabs/puppet/bin/ruby})
        is_expected.to match(%r{puppetdb_host.*localhost})
        is_expected.to match(%r{puppetdb_port.*8080})
        is_expected.to match(%r{log_level.*INFO})
      end
    end

    describe cron do
      it { is_expected.to have_entry('*/30 * * * * /usr/local/bin/puppet_data_connector_enhancer.rb -q -o /opt/puppetlabs/puppet-metrics-collector/puppet_enhanced_metrics.prom').with_user('pe-puppet') }
    end

    describe 'script execution' do
      it 'runs without errors when dependencies are available', if: fact('puppetversion') do
        result = shell('/usr/local/bin/puppet_data_connector_enhancer.rb --help')
        expect(result.exit_code).to eq(0)
        expect(result.stdout).to match(%r{Usage:})
      end
    end
  end

  context 'with custom parameters' do
    let(:pp) do
      <<-MANIFEST
        class { 'puppet_data_connector_enhancer':
          script_path        => '/opt/enhancer/script.rb',
          puppetdb_host      => 'puppet.example.com',
          puppetdb_protocol  => 'https',
          cron_minute        => '*/15',
          cron_user          => 'prometheus',
          dropzone_path      => '/tmp/test_dropzone',
          output_filename    => 'test_metrics.prom',
        }

        # Ensure test dropzone directory exists for this test
        file { '/tmp/test_dropzone':
          ensure => directory,
          before => Class['puppet_data_connector_enhancer'],
        }
      MANIFEST
    end

    it 'applies idempotently' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/opt/enhancer/script.rb') do
      it { is_expected.to exist }
      it { is_expected.to be_file }
      it { is_expected.to be_mode 755 }
      it { is_expected.to be_executable }

      its(:content) do
        is_expected.to match(%r{puppetdb_host.*puppet\.example\.com})
        is_expected.to match(%r{puppetdb_protocol.*https})
        is_expected.to match(%r{/tmp/test_dropzone/test_metrics\.prom})
      end
    end

    describe cron do
      it { is_expected.to have_entry('*/15 * * * * /opt/enhancer/script.rb -q -o /tmp/test_dropzone/test_metrics.prom').with_user('prometheus') }
    end
  end

  context 'when removing the module' do
    let(:pp) do
      <<-MANIFEST
        class { 'puppet_data_connector_enhancer':
          ensure => 'absent',
        }
      MANIFEST
    end

    it 'removes resources cleanly' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/usr/local/bin/puppet_data_connector_enhancer.rb') do
      it { is_expected.not_to exist }
    end

    describe cron do
      it { is_expected.not_to have_entry('*/30 * * * * /usr/local/bin/puppet_data_connector_enhancer.rb').with_user('pe-puppet') }
    end
  end

  context 'when disabling cron job only' do
    let(:pp) do
      <<-MANIFEST
        class { 'puppet_data_connector_enhancer':
          cron_ensure => 'absent',
        }
      MANIFEST
    end

    it 'applies idempotently' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/usr/local/bin/puppet_data_connector_enhancer.rb') do
      it { is_expected.to exist }
      it { is_expected.to be_executable }
    end

    describe cron do
      it { is_expected.not_to have_entry('*/30 * * * * /usr/local/bin/puppet_data_connector_enhancer.rb').with_user('pe-puppet') }
    end
  end
end
