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
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.service')
        }

        it {
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
        }

        it {
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('running')
            .with_enable(true)
        }

        it 'generates the correct script content' do
          is_expected.to contain_file('/usr/local/bin/puppet_data_connector_enhancer.rb')
            .with_content(%r{log_level.*INFO})
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
            'script_path' => '/opt/scripts/enhancer.rb',
            'dropzone' => '/custom/dropzone',
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
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('running')
            .with_enable(true)
        }

        it 'generates the correct script content with custom parameters' do
          is_expected.to contain_file('/opt/scripts/enhancer.rb')
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
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('stopped')
            .with_enable(false)
        }

        it {
          is_expected.to contain_systemd__unit_file(['puppet-data-connector-enhancer.service', 'puppet-data-connector-enhancer.timer'])
            .with_ensure('absent')
        }
      end

      context 'when timer_ensure is absent' do
        let(:params) do
          {
            'timer_ensure' => 'absent'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/bin/puppet_data_connector_enhancer.rb')
            .with_ensure('present')
        }

        it {
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('stopped')
            .with_enable(false)
        }

        it {
          is_expected.to contain_systemd__unit_file(['puppet-data-connector-enhancer.service', 'puppet-data-connector-enhancer.timer'])
            .with_ensure('absent')
        }
      end

      context 'with lookup function for dropzone' do
        let(:params) do
          {
            'dropzone' => '/custom/lookup/path'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .with_ensure('running')
            .with_enable(true)
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

      context 'resource ordering' do
        it 'ensures the script is created before the systemd units' do
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.service')
            .that_requires('File[/usr/local/bin/puppet_data_connector_enhancer.rb]')
        end

        it 'ensures the service is created before the timer' do
          is_expected.to contain_systemd__unit_file('puppet-data-connector-enhancer.timer')
            .that_requires('Systemd::Unit_file[puppet-data-connector-enhancer.service]')
        end

        it 'ensures the timer service starts after unit files are created' do
          is_expected.to contain_service('puppet-data-connector-enhancer.timer')
            .that_requires('Systemd::Unit_file[puppet-data-connector-enhancer.timer]')
        end
      end
    end
  end
end
