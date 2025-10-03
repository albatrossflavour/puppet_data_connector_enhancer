# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer::scm' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          scm_dir: '/opt/puppetlabs/puppet_data_connector_enhancer',
          scm_host: 'https://scm.example.com',
          scm_auth: sensitive('test_token_123'),
          scm_export_retention: 8,
          scm_poll_interval: 30,
          scm_max_wait_time: 900,
          scm_timer_interval: '*:0/30',
          scm_log_file: '/var/log/puppetlabs/puppet_data_connector_enhancer_scm.log',
        }
      end

      it { is_expected.to compile }

      context 'directory management' do
        it 'creates score_data directory' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/score_data').with(
            ensure: 'directory',
            owner: 'pe-puppet',
            group: 'pe-puppet',
            mode: '0755',
          )
        end
      end

      context 'SCM export script' do
        it 'deploys export script with correct permissions' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/export_and_download_cis').with(
            ensure: 'file',
            owner: 'pe-puppet',
            group: 'pe-puppet',
            mode: '0700',
          )
        end

        it 'renders script with correct parameters' do
          content = catalogue.resource('File[/opt/puppetlabs/puppet_data_connector_enhancer/export_and_download_cis]')[:content]
          expect(content).to match(%r{scm_host = 'https://scm.example.com'})
          expect(content).to match(%r{auth = 'Bearer test_token_123'})
          expect(content).to match(%r{export_retention = 8})
          expect(content).to match(%r{poll_interval = 30})
          expect(content).to match(%r{max_wait_time = 900})
        end
      end

      context 'systemd timer' do
        it 'creates systemd timer for SCM export' do
          is_expected.to contain_systemd__timer('puppet-scm-export.timer').with(
            active: true,
            enable: true,
          )
        end

        it 'configures timer with correct interval' do
          timer = catalogue.resource('Systemd::Timer[puppet-scm-export.timer]')
          expect(timer[:timer_content]).to match(%r{OnCalendar=\*:0/30})
        end

        it 'configures service to run as pe-puppet' do
          timer = catalogue.resource('Systemd::Timer[puppet-scm-export.timer]')
          expect(timer[:service_content]).to match(%r{User=pe-puppet})
          expect(timer[:service_content]).to match(%r{Group=pe-puppet})
        end

        it 'configures correct working directory' do
          timer = catalogue.resource('Systemd::Timer[puppet-scm-export.timer]')
          expect(timer[:service_content]).to match(%r{WorkingDirectory=/opt/puppetlabs/puppet_data_connector_enhancer/score_data})
        end
      end

      context 'CSV parsing and resource export' do
        let(:pre_condition) do
          <<-PUPPET
          function puppet_data_connector_enhancer::parse_csv($path) {
            {
              'node1.example.com' => {
                'scan_timestamp' => '2025-01-01T00:00:00Z',
                'scan_type' => 'ad hoc',
                'scanned_benchmark' => 'CIS Ubuntu 22.04',
                'scanned_profile' => 'Level 1',
                'adjusted_compliance_score' => '85',
                'exception_score' => '82',
              }
            }
          }
          PUPPET
        end

        it 'exports file resource for each node' do
          is_expected.to contain_file('cis_score_fact_node1.example.com').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644',
            tag: ['cis_score_node1.example.com'],
          )
        end
      end

      context 'parameter validation' do
        context 'with invalid scm_dir (relative path)' do
          let(:params) do
            super().merge(scm_dir: 'relative/path')
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'scm_dir' expects}) }
        end

        context 'with invalid scm_host (not HTTPS)' do
          let(:params) do
            super().merge(scm_host: 'http://scm.example.com')
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'scm_host' expects}) }
        end

        context 'with invalid scm_export_retention (zero)' do
          let(:params) do
            super().merge(scm_export_retention: 0)
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'scm_export_retention' expects}) }
        end

        context 'with invalid scm_poll_interval (negative)' do
          let(:params) do
            super().merge(scm_poll_interval: -1)
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'scm_poll_interval' expects}) }
        end
      end
    end
  end
end
