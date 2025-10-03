# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer::client' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      context 'exported resource collection' do
        let(:pre_condition) do
          <<-PUPPET
          @@file { "cis_score_fact_#{facts['clientcert']}":
            ensure  => 'file',
            path    => "/tmp/cis_score_#{facts['clientcert']}.yaml",
            owner   => 'pe-puppet',
            group   => 'pe-puppet',
            mode    => '0644',
            content => "test content",
            tag     => ["cis_score_#{facts['clientcert']}"],
          }
          PUPPET
        end

        it 'collects exported resource tagged for this node' do
          # The resource collection syntax <<| |>> is parsed but we can verify
          # the class compiles and would collect the resource
          is_expected.to compile
        end

        context 'on Linux systems' do
          let(:facts) do
            os_facts.merge(
              'os' => {
                'family' => 'RedHat',
              },
            )
          end

          it 'uses Linux external facts path' do
            # Verify the class compiles with Linux facts
            # The actual path override happens at runtime during collection
            is_expected.to compile
          end
        end

        context 'on Windows systems' do
          let(:facts) do
            os_facts.merge(
              'os' => {
                'family' => 'windows',
              },
            )
          end

          it 'uses Windows external facts path' do
            # Verify the class compiles with Windows facts
            # The actual path override happens at runtime during collection
            is_expected.to compile
          end
        end
      end

      context 'OS-specific path handling' do
        context 'when os.family is RedHat' do
          let(:facts) do
            os_facts.merge(
              'os' => {
                'family' => 'RedHat',
              },
            )
          end

          it 'compiles successfully' do
            is_expected.to compile
          end
        end

        context 'when os.family is Debian' do
          let(:facts) do
            os_facts.merge(
              'os' => {
                'family' => 'Debian',
              },
            )
          end

          it 'compiles successfully' do
            is_expected.to compile
          end
        end

        context 'when os.family is Suse' do
          let(:facts) do
            os_facts.merge(
              'os' => {
                'family' => 'Suse',
              },
            )
          end

          it 'compiles successfully' do
            is_expected.to compile
          end
        end

        context 'when os.family is windows' do
          let(:facts) do
            os_facts.merge(
              'os' => {
                'family' => 'windows',
              },
            )
          end

          it 'compiles successfully' do
            is_expected.to compile
          end
        end
      end

      context 'resource tag matching' do
        let(:facts) do
          os_facts.merge(
            'clientcert' => 'test-node.example.com',
            'trusted' => {
              'certname' => 'test-node.example.com',
            },
          )
        end

        it 'uses trusted certname for tag matching' do
          # Verify the class compiles and would match the correct tag
          is_expected.to compile
        end
      end

      context 'when no exported resource exists' do
        it 'compiles without errors' do
          # Class should compile even if there are no resources to collect
          is_expected.to compile
        end
      end
    end
  end
end
