# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'class { "puppet_data_connector": }' }
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
            .with_mode('0755')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'creates systemd service unit file' do
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.service')
        end

        it 'creates systemd timer' do
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('running')
            .with_enable(true)
        end

        it 'generates the correct script content' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{class PrometheusMetricsGenerator})
        end

        it 'does not include SCM classes by default' do
          is_expected.not_to contain_class('puppet_data_connector_enhancer::scm')
          is_expected.not_to contain_class('puppet_data_connector_enhancer::client')
        end
      end

      context 'with SCM collection enabled' do
        let(:facts) do
          super().merge(
            'puppet_server' => 'puppet.example.com',
            'clientcert' => 'puppet.example.com',
          )
        end
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
            .with_mode('0755')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'configures timer with custom interval' do
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('running')
            .with_enable(true)
        end

        it 'generates the correct script content with custom parameters' do
          is_expected.to contain_file('/opt/scripts/enhancer')
            .with_content(%r{http_timeout:.*30})
            .with_content(%r{http_retries:.*5})
            .with_content(%r{retry_delay:.*5\.0})
            .with_content(%r{output_file:.*'/custom/dropzone/custom_metrics\.prom'})
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
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('stopped')
            .with_enable(false)
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
            .with_ensure('absent')
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
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('stopped')
            .with_enable(false)
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
            .with_ensure('absent')
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

          it { is_expected.to compile.and_raise_error(%r{scm_server and/or scm_auth}) }
        end

        context 'when enable_scm_collection is true but scm_auth is missing' do
          let(:params) do
            {
              'enable_scm_collection' => true,
              'scm_server' => 'scm.example.com',
            }
          end

          it { is_expected.to compile.and_raise_error(%r{scm_server and/or scm_auth}) }
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

      context 'with custom_queries parameter' do
        let(:params) do
          super().merge(
            'custom_queries' => [
              {
                'name'       => 'puppet_custom_nginx_version',
                'type'       => 'gauge',
                'help'       => 'Nginx version per node',
                'endpoint'   => 'fact',
                'fact_name'  => 'packages',
                'labels'     => {
                  'node'        => 'certname',
                  'environment' => 'environment',
                  'version'     => 'value.nginx.version',
                },
              },
            ],
          )
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom queries YAML file' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .with_ensure('file')
            .with_mode('0644')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end

        it 'renders YAML with metric name' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .with_content(%r{name: "puppet_custom_nginx_version"})
        end

        it 'renders YAML with endpoint type' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .with_content(%r{endpoint: "fact"})
        end

        it 'renders YAML with fact_name' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .with_content(%r{fact_name: "packages"})
        end

        it 'passes custom_queries_file to script template' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{custom_queries\.yaml})
        end

        it 'includes require yaml in script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{require 'yaml'})
        end

        it 'includes collect_custom_metrics method in script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{def collect_custom_metrics})
        end
      end

      context 'with empty custom_queries array' do
        let(:params) do
          super().merge(
            'custom_queries' => [],
          )
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom queries file with empty metrics' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .with_ensure('file')
            .with_content(%r{^---\nmetrics:\n$})
        end
      end

      context 'without custom_queries parameter' do
        it { is_expected.to compile.with_all_deps }

        it 'ensures custom queries file is absent' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .with_ensure('absent')
        end
      end

      context 'with custom custom_queries_file path' do
        let(:params) do
          super().merge(
            'custom_queries' => [
              {
                'name'     => 'puppet_custom_test',
                'type'     => 'gauge',
                'help'     => 'Test metric',
                'endpoint' => 'pql',
                'pql_query' => 'nodes { }',
              },
            ],
            'custom_queries_file' => '/etc/puppet/custom_queries.yaml',
          )
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom queries file at specified path' do
          is_expected.to contain_file('/etc/puppet/custom_queries.yaml')
            .with_ensure('file')
        end

        it 'passes custom path to script template' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .with_content(%r{/etc/puppet/custom_queries\.yaml})
        end
      end

      context 'custom queries resource ordering' do
        let(:params) do
          super().merge(
            'custom_queries' => [
              {
                'name'     => 'puppet_custom_test',
                'type'     => 'gauge',
                'help'     => 'Test metric',
                'endpoint' => 'fact',
                'fact_name' => 'os',
              },
            ],
          )
        end

        it 'ensures custom queries file is created before script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .that_requires('File[/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml]')
        end

        it 'ensures base directory is created before custom queries file' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/custom_queries.yaml')
            .that_requires('File[/opt/puppetlabs/puppet_data_connector_enhancer]')
        end
      end

      context 'resource ordering' do
        it 'ensures base directory is created before script' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer/puppet_data_connector_enhancer')
            .that_requires('File[/opt/puppetlabs/puppet_data_connector_enhancer]')
        end

        it 'ensures script is created before timer' do
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
            .that_requires('Systemd::Unit_file[puppet-data-connector-enhancer.service]')
        end
      end
    end
  end
end
