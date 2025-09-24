# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('puppet_data_connector_enhancer') }

        it {
          is_expected.to contain_file('/usr/local/bin/puppet_data_connector_enhancer.rb')
            .with_ensure('present')
            .with_mode('0755')
            .with_owner('root')
            .with_group('root')
        }

        it {
          is_expected.to contain_cron('puppet_data_connector_enhancer')
            .with_ensure('present')
            .with_user('pe-puppet')
            .with_minute('*/30')
            .with_hour('*')
        }

        it 'generates the correct script content' do
          is_expected.to contain_file('/usr/local/bin/puppet_data_connector_enhancer.rb')
            .with_content(%r{puppetdb_host.*localhost})
            .with_content(%r{puppetdb_port.*8080})
            .with_content(%r{puppetdb_protocol.*http})
            .with_content(%r{infra_assistant_host.*localhost})
            .with_content(%r{infra_assistant_port.*8145})
            .with_content(%r{log_level.*INFO})
        end
      end

      context 'with custom parameters' do
        let(:params) do
          {
            'puppetdb_host' => 'puppet.example.com',
            'puppetdb_port' => 8081,
            'puppetdb_protocol' => 'https',
            'infra_assistant_host' => 'infra.example.com',
            'infra_assistant_port' => 8146,
            'infra_assistant_protocol' => 'http',
            'http_timeout' => 30,
            'http_retries' => 5,
            'retry_delay' => 5.0,
            'log_level' => 'DEBUG',
            'cron_minute' => '*/15',
            'cron_hour' => '1-23',
            'cron_user' => 'prometheus',
            'script_path' => '/opt/scripts/enhancer.rb',
            'dropzone_path' => '/custom/dropzone',
            'output_filename' => 'custom_metrics.prom'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/opt/scripts/enhancer.rb')
            .with_ensure('present')
            .with_mode('0755')
            .with_owner('root')
            .with_group('root')
        }

        it {
          is_expected.to contain_cron('puppet_data_connector_enhancer')
            .with_ensure('present')
            .with_user('prometheus')
            .with_minute('*/15')
            .with_hour('1-23')
            .with_command('/opt/scripts/enhancer.rb -q -o /custom/dropzone/custom_metrics.prom')
        }

        it 'generates the correct script content with custom parameters' do
          is_expected.to contain_file('/opt/scripts/enhancer.rb')
            .with_content(%r{puppetdb_host.*puppet\.example\.com})
            .with_content(%r{puppetdb_port.*8081})
            .with_content(%r{puppetdb_protocol.*https})
            .with_content(%r{infra_assistant_host.*infra\.example\.com})
            .with_content(%r{infra_assistant_port.*8146})
            .with_content(%r{infra_assistant_protocol.*http})
            .with_content(%r{http_timeout.*30})
            .with_content(%r{http_retries.*5})
            .with_content(%r{retry_delay.*5\.0})
            .with_content(%r{log_level.*DEBUG})
            .with_content(%r{/custom/dropzone/custom_metrics\.prom})
        end
      end

      context 'when ensure is absent' do
        let(:params) do
          {
            'ensure' => 'absent'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/bin/puppet_data_connector_enhancer.rb')
            .with_ensure('absent')
        }

        it {
          is_expected.to contain_cron('puppet_data_connector_enhancer')
            .with_ensure('absent')
        }
      end

      context 'when cron_ensure is absent' do
        let(:params) do
          {
            'cron_ensure' => 'absent'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/bin/puppet_data_connector_enhancer.rb')
            .with_ensure('present')
        }

        it {
          is_expected.to contain_cron('puppet_data_connector_enhancer')
            .with_ensure('absent')
        }
      end

      context 'with lookup function for dropzone_path' do
        let(:params) do
          {
            'dropzone_path' => '/custom/lookup/path'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_cron('puppet_data_connector_enhancer')
            .with_command('/usr/local/bin/puppet_data_connector_enhancer.rb -q -o /custom/lookup/path/puppet_enhanced_metrics.prom')
        }
      end

      context 'parameter validation' do
        context 'with invalid ensure value' do
          let(:params) do
            {
              'ensure' => 'invalid'
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'ensure' expects}) }
        end

        context 'with invalid puppetdb_protocol' do
          let(:params) do
            {
              'puppetdb_protocol' => 'ftp'
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'puppetdb_protocol' expects}) }
        end

        context 'with invalid http_timeout' do
          let(:params) do
            {
              'http_timeout' => 0
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'http_timeout' expects}) }
        end

        context 'with invalid http_timeout too high' do
          let(:params) do
            {
              'http_timeout' => 301
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'http_timeout' expects}) }
        end

        context 'with invalid http_retries' do
          let(:params) do
            {
              'http_retries' => 0
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'http_retries' expects}) }
        end

        context 'with invalid log_level' do
          let(:params) do
            {
              'log_level' => 'INVALID'
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'log_level' expects}) }
        end

        context 'with invalid script_path (relative)' do
          let(:params) do
            {
              'script_path' => 'relative/path'
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'script_path' expects}) }
        end

        context 'with invalid dropzone_path (relative)' do
          let(:params) do
            {
              'dropzone_path' => 'relative/path'
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'dropzone_path' expects}) }
        end
      end

      context 'resource ordering' do
        it 'ensures the script is created before the cron job' do
          is_expected.to contain_cron('puppet_data_connector_enhancer')
            .that_requires('File[/usr/local/bin/puppet_data_connector_enhancer.rb]')
        end
      end
    end
  end
end
