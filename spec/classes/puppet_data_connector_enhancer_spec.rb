# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          'dropzone' => '/opt/puppetlabs/puppet/prometheus_dropzone',
        }
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('puppet_data_connector_enhancer') }

        it 'creates base directory' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer')
            .with_ensure('directory')
            .with_mode('0755')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'creates main script with correct permissions' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_ensure('present')
            .with_mode('0700')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'creates systemd timer' do
          is_expected.to contain_systemd__timer('puppet-data-connector-enhancer.timer')
            .with_active(true)
            .with_enable(true)
        end

        it 'generates the correct script content' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{log_level.*INFO})
        end

        it 'does not include SCM classes by default' do
          is_expected.not_to contain_class('puppet_data_connector_enhancer::scm')
          is_expected.not_to contain_class('puppet_data_connector_enhancer::client')
        end
      end

      context 'with SCM collection enabled' do
        let(:params) do
          super().merge(
            'enable_scm_collection' => true,
            'scm_server' => 'scm.example.com',
            'scm_auth' => sensitive('test_token_123'),
          )
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes SCM class' do
          is_expected.to contain_class('puppet_data_connector_enhancer::scm')
        end

        it 'includes client class' do
          is_expected.to contain_class('puppet_data_connector_enhancer::client')
        end
      end

      context 'with SCM collection disabled' do
        let(:params) do
          {
            'enable_scm_collection' => false,
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not include SCM class' do
          is_expected.not_to contain_class('puppet_data_connector_enhancer::scm')
        end

        it 'does not include client class' do
          is_expected.not_to contain_class('puppet_data_connector_enhancer::client')
        end
      end

      context 'with custom parameters' do
        let(:params) do
          {
            'http_timeout' => 30,
            'http_retries' => 5,
            'retry_delay' => 5.0,
            'log_level' => 'DEBUG',
            'timer_interval' => '*:0/15',
            'script_path' => '/opt/scripts/enhancer',
            'dropzone' => '/custom/dropzone',
            'output_filename' => 'custom_metrics.prom'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom script path' do
          is_expected.to contain_file('/opt/scripts/enhancer')
            .with_ensure('present')
            .with_mode('0700')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'configures timer with custom interval' do
          is_expected.to contain_systemd__timer('puppet-data-connector-enhancer.timer')
            .with_active(true)
            .with_enable(true)
        end

        it 'generates the correct script content with custom parameters' do
          is_expected.to contain_file('/opt/scripts/enhancer')
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

        it 'removes main script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_ensure('absent')
        end

        it 'stops and disables timer' do
          is_expected.to contain_systemd__timer('puppet-data-connector-enhancer.timer')
            .with_active(false)
            .with_enable(false)
        end
      end

      context 'when timer_ensure is absent' do
        let(:params) do
          {
            'timer_ensure' => 'absent'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'keeps main script present' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_ensure('present')
        end

        it 'stops and disables timer' do
          is_expected.to contain_systemd__timer('puppet-data-connector-enhancer.timer')
            .with_active(false)
            .with_enable(false)
        end
      end

      context 'with custom dropzone path' do
        let(:params) do
          {
            'dropzone' => '/custom/dropzone/path'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom dropzone in script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{/custom/dropzone/path})
        end
      end

      context 'with custom scm_dir' do
        let(:params) do
          {
            'scm_dir' => '/custom/scm/location',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom scm directory' do
          is_expected.to contain_file('/custom/scm/location')
            .with_ensure('directory')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'creates script in custom location' do
          is_expected.to contain_file('/custom/scm/location/puppet_data_connector_enhancer')
            .with_ensure('present')
        end
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
      end

      context 'SCM parameter validation' do
        context 'when enable_scm_collection is true but scm_server is missing' do
          let(:params) do
            {
              'enable_scm_collection' => true,
              'scm_auth' => sensitive('test_token'),
            }
          end

          it { is_expected.to compile.and_raise_error(%r{scm_server.*required}) }
        end

        context 'when enable_scm_collection is true but scm_auth is missing' do
          let(:params) do
            {
              'enable_scm_collection' => true,
              'scm_server' => 'scm.example.com',
            }
          end

          it { is_expected.to compile.and_raise_error(%r{scm_auth.*required}) }
        end

        context 'with invalid scm_server (not FQDN)' do
          let(:params) do
            {
              'enable_scm_collection' => true,
              'scm_server' => 'not_a_fqdn',
              'scm_auth' => sensitive('test_token'),
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'scm_server' expects}) }
        end

        context 'with invalid scm_dir (relative path)' do
          let(:params) do
            {
              'scm_dir' => 'relative/path',
            }
          end

          it { is_expected.to compile.and_raise_error(%r{parameter 'scm_dir' expects}) }
        end
      end

      context 'resource ordering' do
        it 'ensures base directory is created before script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .that_requires('File[/opt/puppetlabs/puppet_data_connector_enhancer]')
        end

        it 'ensures script is created before timer' do
          is_expected.to contain_systemd__timer('puppet-data-connector-enhancer.timer')
            .that_requires('File[/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer]')
        end
      end
    end
  end
end
