# Testing Patterns

**Analysis Date:** 2026-04-05

## Test Framework

**Runner:**
- RSpec via `puppetlabs_spec_helper` ~> 8.0
- Config: `.rspec` (color output, documentation format)
- RuboCop plugin: `rubocop-rspec` 2.19

**Assertion library:**
- RSpec built-in matchers
- `rspec-puppet` matchers (`contain_*`, `compile`, `with_*`, `that_requires`)
- `rspec-puppet-facts` for cross-platform OS matrix testing

**Key gems:**
- `puppetlabs_spec_helper` ~> 8.0 - test harness wiring
- `rspec-puppet-facts` ~> 4.0 - OS fact matrix
- `facterdb` ~> 2.1 - fact database for OS combinations
- `puppet_litmus` ~> 1.0 - acceptance test runner
- `serverspec` ~> 2.41 - acceptance test assertions
- `simplecov-console` ~> 0.9 - coverage reporting

**Run commands:**

```bash
bundle exec rake spec              # Run all unit tests
bundle exec rake spec_prep         # Install fixture modules
bundle exec rake lint              # Run puppet-lint
bundle exec rake rubocop           # Run RuboCop
bundle exec rake validate          # Syntax validation
bundle exec rake test              # lint + validate + spec
```

## Test File Organisation

**Location:**
- Unit tests: `spec/classes/` (one file per manifest class)
- Function tests: `spec/functions/` (one file per custom function)
- Acceptance tests: `spec/acceptance/`
- Shared config: `spec/spec_helper.rb`
- Default facts: `spec/default_facts.yml`

**Naming:**
- Class specs: `{class_name}_spec.rb` (e.g., `puppet_data_connector_enhancer_spec.rb`)
- Subclass specs: `{subclass_name}_spec.rb` (e.g., `scm_spec.rb`, `client_spec.rb`)
- Function specs: `{function_name}_spec.rb` (e.g., `parse_csv_spec.rb`)

**Structure:**

```
spec/
├── acceptance/
│   └── class_spec.rb          # Litmus acceptance tests
├── classes/
│   ├── puppet_data_connector_enhancer_spec.rb
│   ├── scm_spec.rb
│   └── client_spec.rb
├── functions/
│   └── parse_csv_spec.rb
├── default_facts.yml
└── spec_helper.rb
```

## Test Structure

**Suite organisation:**

All class specs iterate over the `on_supported_os` matrix from `rspec-puppet-facts`. The outer loop sets OS facts; contexts nest inside for specific scenarios.

```ruby
# frozen_string_literal: true

require 'spec_helper'

describe 'puppet_data_connector_enhancer' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'class { "puppet_data_connector": }' }
      let(:params) do
        { 'dropzone' => '/opt/puppetlabs/puppet/prometheus_dropzone' }
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it 'creates base directory' do
          is_expected.to contain_file('/opt/puppetlabs/puppet_data_connector_enhancer')
            .with_ensure('directory')
            .with_mode('0755')
            .with_owner('pe-puppet')
            .with_group('pe-puppet')
        end
      end
    end
  end
end
```

**Patterns:**
- `let(:facts)` sets OS facts from the matrix
- `let(:params)` sets class parameters; use `super().merge(...)` to override in nested contexts
- `let(:pre_condition)` declares dependencies that must be in the catalogue
- Each `it` block tests one assertion or one small group of related assertions
- Named `it` blocks (`it 'creates base directory' do`) preferred over one-liners for non-trivial checks

## Mocking

**Framework:** RSpec built-in mocks (configured with `c.mock_with :rspec` in `spec_helper.rb`)

**RuboCop enforced style:** `receive` style (not `have_received`)

**File system mocking pattern** (used in function specs):

```ruby
before do
  allow(File).to receive(:exist?).and_call_original
  allow(File).to receive(:exist?).with('/tmp/test.csv').and_return(true)

  csv_rows = CSV.parse(csv_content, headers: true)
  allow(CSV).to receive(:foreach).and_call_original
  allow(CSV).to receive(:foreach).with('/tmp/test.csv', any_args) do |&block|
    csv_rows.each { |row| block.call(row) }
  end
end
```

**Key pattern:** Always call `.and_call_original` first, then set the specific stub. This ensures other file system calls are not accidentally intercepted.

**Puppet warning mocking:**

```ruby
it 'logs warning message' do
  expect(Puppet).to receive(:warning).with(/CIS score CSV not found/)
  subject.execute('/tmp/nonexistent.csv')
end
```

**What to mock:**
- `File.exist?` for function tests that read from disk
- `CSV.foreach` for function tests that parse files
- `Puppet.warning` when testing warning output

**What NOT to mock:**
- Puppet catalogue compilation (use `rspec-puppet` matchers instead)
- OS facts (use `rspec-puppet-facts` matrix)

## Fixtures and Factories

**Module dependencies** declared in `.fixtures.yml` and installed by `spec_prep`:

```yaml
fixtures:
  forge_modules:
    stdlib: "puppetlabs/stdlib"
    systemd: "puppet/systemd"
```

**Default facts** in `spec/default_facts.yml`:

```yaml
networking:
  ip: "172.16.254.254"
is_pe: false
```

These override values from `facterdb` and are merged in `spec_helper.rb` via `add_custom_fact`.

**Inline test data** (CSV fixtures in function specs):

```ruby
let(:csv_content) do
  <<~CSV
    Node Name,Scan Timestamp,...
    node1.example.com,2025-01-01T10:00:00Z,...
  CSV
end
```

**Location:** No separate fixtures directory for test data. Inline `let` blocks define test data close to the test.

## Coverage

**Requirements:** `RSpec::Puppet::Coverage.report!(0)` - 0% minimum enforced (coverage reporting enabled but no hard threshold)

**View coverage:**

```bash
bundle exec rake spec              # Coverage summary printed to console via simplecov-console
```

## Test Types

**Unit tests** (`spec/classes/`, `spec/functions/`):
- Scope: catalogue compilation, resource attributes, parameter validation, function return values
- Do not hit network or filesystem (all mocked)
- Run against every OS in the `on_supported_os` matrix
- Puppet strict mode enabled: `Puppet.settings[:strict] = :warning` and `strict_variables = true`

**Function tests** (`spec/functions/`):
- Test the Ruby function in isolation via `subject.execute(...)`
- Mock all I/O (file existence, CSV parsing)
- Cover: happy path, missing file, empty file, malformed data, edge cases (duplicates, quoted fields, uppercase names)

**Acceptance tests** (`spec/acceptance/`):
- Framework: Puppet Litmus + Serverspec
- Scope: full apply on a real system, idempotency checks, file/service assertions
- Pattern: apply twice and assert `catch_changes` on second run
- Use `serverspec` resource types (`file`, `service`) for assertions

## Common Patterns

**Compile check:**

```ruby
it { is_expected.to compile.with_all_deps }
```

**Resource attribute assertions (chained):**

```ruby
it 'creates main script with correct permissions' do
  is_expected.to contain_file('/path/to/script')
    .with_ensure('present')
    .with_mode('0755')
    .with_owner('pe-puppet')
    .with_group('pe-puppet')
end
```

**Content regex matching:**

```ruby
it 'generates the correct script content' do
  is_expected.to contain_file('/path/to/script')
    .with_content(%r{class PrometheusMetricsGenerator})
end
```

**Direct catalogue resource access** (when chained matchers are insufficient):

```ruby
it 'renders script with correct parameters' do
  content = catalogue.resource('File[/path/to/script]')[:content]
  expect(content).to match(%r{scm_host = 'https://scm.example.com'})
end
```

**Parameter validation errors:**

```ruby
context 'with invalid ensure value' do
  let(:params) { { 'ensure' => 'invalid' } }
  it { is_expected.to compile.and_raise_error(%r{parameter 'ensure' expects}) }
end
```

**Inheriting params in nested contexts:**

```ruby
let(:params) do
  super().merge('enable_scm_collection' => true)
end
```

**Sensitive values in tests:**

```ruby
let(:params) do
  { 'scm_auth' => sensitive('test_token_123') }
end
```

**Resource ordering assertions:**

```ruby
it 'ensures base directory is created before script' do
  is_expected.to contain_file('/path/to/script')
    .that_requires('File[/path/to/dir]')
end
```

**Skipped tests:** Commented-out context blocks are retained with a `# NOTE:` explanation of why they are skipped, rather than deleted. See `spec/classes/scm_spec.rb` lines 81-88 for an example of this pattern.

---

*Testing analysis: 2026-04-05*
