# Technology Stack

**Analysis Date:** 2026-04-05

## Languages

**Primary:**

- Ruby - Used for all runtime scripts deployed to managed nodes
  (`templates/puppet_data_connector_enhancer.epp`,
  `templates/export_and_download_cis.rb.epp`) and the custom Puppet function
  (`lib/puppet/functions/puppet_data_connector_enhancer/parse_csv.rb`)
- Puppet DSL - Module manifests (`manifests/*.pp`) and EPP templates
  (`templates/*.epp`)

**Secondary:**

- Ruby (test/dev tooling only) - RSpec tests in `spec/`, Rake tasks in
  `Rakefile`

## Runtime

**Environment:**

- Puppet Enterprise >= 7.24, < 9.0.0 (required)
- Ruby runtime provided by PE: `/opt/puppetlabs/puppet/bin/ruby` (shebang in
  deployed scripts)
- Target OS: RHEL/CentOS/Rocky/AlmaLinux 7-9, Debian 10-12, Ubuntu 18.04-22.04

**Package Manager:**

- Bundler (Gemfile present) - development and test dependencies only
- PDK 3.4.0 for module development workflows
- Lockfile: Not committed (standard PDK pattern)

## Frameworks

**Core:**

- Puppet module framework - The entire deliverable is a Puppet module published
  to Puppet Forge as `albatrossflavour-puppet_data_connector_enhancer` v1.3.0
- PDK (Puppet Development Kit) 3.4.0 - Module scaffolding, templating, and
  release tooling

**Testing:**

- RSpec ~> (via `puppetlabs_spec_helper` ~> 8.0) - Unit test runner
- rspec-puppet - Puppet-specific RSpec matchers for manifest testing
- rspec-puppet-facts ~> 4.0 - Multi-platform fact simulation
- facterdb ~> 2.1 - Offline Facter fact data for tests
- puppet_litmus ~> 1.0 - Acceptance/integration test framework
- serverspec ~> 2.41 - Server-side acceptance test assertions
- simplecov-console ~> 0.9 - Test coverage reporting

**Build/Dev:**

- puppet-strings ~> 4.0 - Documentation generation from YARD-annotated manifests
- puppet-blacksmith ~> 7.0 - Forge module release automation
- puppetlabs_spec_helper ~> 8.0 - Rake task integration and fixture management
- parallel_tests = 3.12.1 - Parallel spec execution
- puppet-debugger ~> 1.0 - Interactive Puppet debugging REPL

## Key Dependencies

**Critical (Puppet module dependencies declared in `metadata.json`):**

- `puppetlabs/puppet_data_connector` >= 1.0.0, < 2.0.0 - The premium module
  this enhances; provides the dropzone path via Hiera lookup
- `puppetlabs/stdlib` >= 9.0.0, < 10.0.0 - Provides `Stdlib::Absolutepath`,
  `Stdlib::Fqdn`, `Stdlib::HTTPSUrl` types used throughout manifests
- `puppet/systemd` >= 4.0.0, < 8.0.0 - Manages systemd unit files and timers
  via `systemd::unit_file` and `systemd::timer` resources

**Development:**

- rubocop ~> 1.50.0 + rubocop-performance 1.16.0 + rubocop-rspec 2.19.0 -
  Style enforcement (target Ruby 2.6 per `.rubocop.yml`)
- voxpupuli-puppet-lint-plugins ~> 5.0 - Extended puppet-lint rules
- metadata-json-lint ~> 4.0 - `metadata.json` validation
- dependency_checker ~> 1.0.0 - Dependency version constraint validation
- pry ~> 0.10 - Interactive debugger

**Runtime Ruby stdlib (no external gems required on target nodes):**

The deployed scripts use only Ruby stdlib: `net/http`, `openssl`, `uri`,
`json`, `time`, `fileutils`, `logger`, `csv`, `set`, `timeout`, `optparse`

## Configuration

**Environment (deployed script reads these at runtime):**

- `PUPPETDB_HOST` - PuppetDB hostname (default: `localhost`)
- `PUPPETDB_PORT` - PuppetDB port (default: `8080`)
- `PUPPETDB_PROTOCOL` - Protocol for PuppetDB (default: `http`)
- `INFRA_ASSISTANT_HOST` - Infrastructure Assistant hostname (default:
  `localhost`)
- `INFRA_ASSISTANT_PORT` - Port (default: `8145`)
- `INFRA_ASSISTANT_PROTOCOL` - Protocol (default: `https`)
- `HTTP_TIMEOUT`, `HTTP_RETRIES`, `RETRY_DELAY` - HTTP client tuning
- `OUTPUT_FILE` - Override output file path
- `LOG_LEVEL` - Runtime log level override
- `MANAGE_OWNERSHIP`, `FILE_OWNER`, `FILE_GROUP`, `FILE_MODE` - Output file
  ownership control

**Module (Puppet class parameters in `manifests/init.pp`):**

- All configuration passed as Puppet class parameters with validated types
- `scm_auth` handled as `Sensitive[String[1]]` to prevent value exposure in
  logs and reports
- `dropzone` path auto-discovered via Hiera: `lookup('puppet_data_connector::dropzone')`

**Build:**

- `pdk.yaml` - PDK ignore list (empty overrides)
- `.rubocop.yml` - RuboCop configuration (targets Ruby 2.6)
- `.puppet-lint.rc` - puppet-lint rule overrides
- `hiera.yaml` (Hiera 5) - Module data hierarchy: OS name/version -> OS family
  -> common
- `Rakefile` - Rake tasks via PDK/puppetlabs_spec_helper integration

## Platform Requirements

**Development:**

- PDK 3.4.0
- Ruby (version managed by PDK)
- Bundler

**Production:**

- Puppet Enterprise >= 7.24, < 9.0.0
- Target nodes: systemd-based Linux (RHEL family or Debian family)
- Script installed at `/opt/puppetlabs/puppet_data_connector_enhancer/`
  (default) and executed as `pe-puppet` user
- Output written to PE prometheus dropzone (default:
  `/opt/puppetlabs/puppet/prometheus_dropzone/`)

---

*Stack analysis: 2026-04-05*
