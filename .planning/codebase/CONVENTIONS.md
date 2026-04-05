# Coding Conventions

**Analysis Date:** 2026-04-05

## Languages and Their Conventions

This is a Puppet module with three distinct languages in use, each with its own style rules.

### Puppet (manifests, templates)

**Files:**
- Manifests: `snake_case.pp` in `manifests/`
- Templates: `snake_case.epp` in `templates/`
- One class per file; filename matches the class name after the module prefix

**Classes:**
- Fully qualified with module namespace: `puppet_data_connector_enhancer`, `puppet_data_connector_enhancer::scm`, `puppet_data_connector_enhancer::client`
- Parameters use `snake_case`
- Private subclasses are documented as private in their header comment

**Parameters:**
- Always typed with explicit Puppet types (e.g., `Enum['present', 'absent']`, `Stdlib::Absolutepath`, `Integer[1, 300]`)
- Optional params use `Optional[Type]` and default to `undef`
- Sensitive values use `Sensitive[String[1]]` type
- Defaults set inline in the parameter list, not via `params.pp`

**Example parameter block pattern** (from `manifests/init.pp`):

```puppet
class puppet_data_connector_enhancer (
  Enum['present', 'absent'] $ensure         = 'present',
  Optional[Stdlib::Absolutepath] $script_path = undef,
  Integer[1, 300] $http_timeout              = 5,
  Boolean $enable_scm_collection             = false,
  Optional[Sensitive[String[1]]] $scm_auth   = undef,
) {
```

**Resource declarations:**
- Arrow-aligned attribute values within a resource block
- `require` declared inline as resource attribute, not separate `->` chaining where possible
- `epp()` used for all template rendering (not `template()`)
- Named parameters passed to EPP as explicit hash

**Lint rules** (enforced via `.puppet-lint.rc` and `Rakefile`):
- `--fail-on-warnings`: warnings are treated as errors
- Line length checks disabled (80-char and 140-char)
- `autoloader_layout` check disabled
- `documentation` check disabled
- `arrow_alignment` check disabled

### Ruby (functions, spec files)

**Style enforcer:** RuboCop 1.50 with rubocop-performance 1.16 and rubocop-rspec 2.19

**Key enforced styles** (from `.rubocop.yml`):

- `# frozen_string_literal: true` at top of every `.rb` file
- Line length max: 200 (not default 80)
- Block delimiters: braces for chaining (`braces_for_chaining`)
- Class/module children: compact style (`compact`)
- Format strings: `%` style (e.g., `"value: %s" % variable`)
- Lambda syntax: literal (`->` not `lambda`)
- Regexp literals: percent-r style (`%r{pattern}` not `/pattern/`)
- Trailing commas on multiline arguments and array literals
- Symbol arrays: bracket style (`[:foo, :bar]` not `%i[foo bar]`)
- Word arrays: bracket style (`['foo', 'bar']` not `%w[foo bar]`)
- Ternary conditions: parentheses required on complex expressions

**Naming:**
- Methods: `snake_case`
- Classes: `PascalCase` (e.g., `MetricsCollectionError`, `PrometheusMetricsGenerator`)
- Constants: `SCREAMING_SNAKE_CASE`
- All metrics cops disabled (no method length limits, no ABC size limits)

**Imports/requires:**
- `require` statements at top of file, before any code
- Stdlib requires before gem requires before local requires

### EPP Templates

- Parameter block at top using `<%- | ... | -%>` syntax with explicit types
- All parameters typed (mirrors the manifest that renders the template)
- Generated content is Ruby scripts with `#!/opt/puppetlabs/puppet/bin/ruby` shebang

## Documentation

**Puppet classes:** Full YARD-style Puppet Strings documentation on every public class parameter. Format:

```puppet
# @summary One-line description
#
# Multi-line description as needed.
#
# @param param_name
#   Description of the parameter.
#
# @example Description
#   class { 'module_name': param => value }
```

**Ruby functions:** YARD-style comment block before `create_function`, with `@param` and `@return` tags. Inline `@example` block showing usage and return value.

**Private classes:** Explicitly noted as private in the summary comment.

## Error Handling

**Puppet manifests:**
- Explicit validation using `fail()` for business logic errors (e.g., missing required params when a feature is enabled)
- Type constraints in parameter declarations catch type errors at compile time
- Pattern: validate early, fail with a descriptive message

```puppet
if $enable_scm_collection {
  if !$scm_server or !$scm_auth {
    fail('enable_scm_collection is true but scm_server and/or scm_auth are not configured')
  }
}
```

**Ruby functions:**
- `rescue Puppet::ParseError` re-raised to fail catalog compilation
- `rescue StandardError => e` wraps unknown errors in `Puppet::ParseError` with context
- `Puppet.warning()` for non-fatal issues (missing file on first run, empty CSV)
- Early return of empty hash rather than raising on missing optional files

**Generated Ruby scripts (EPP):**
- Custom exception classes inheriting `StandardError` with extra context attributes
- Retry loops with exponential backoff for HTTP requests
- `@collection_errors` array accumulated during run; reported at end rather than halting on first failure

## Logging

**Framework:** Ruby `Logger` class (in generated scripts)

**Log levels:** `DEBUG`, `INFO`, `WARN`, `ERROR` (controlled via `log_level` param, overridable via `LOG_LEVEL` env var)

**Pattern:** Log to `STDERR` when writing output to a file, `STDOUT` otherwise

**Puppet functions:** `Puppet.warning()` for warnings surfaced during catalog compilation

## Comments

- Inline comments above logical blocks, not beside code
- `# NOTE:` prefix for explanatory comments about omitted or skipped code
- Commented-out test blocks retained with explanatory note rather than deleted
- Hiera data file uses inline comments explaining non-obvious defaults

## Module Structure Conventions

**Hiera data:** Module defaults in `data/common.yaml`, with `hiera.yaml` at module root defining the data hierarchy

**Files directory:** Static assets (Grafana dashboard JSON) served unchanged via `puppet:///`

**Examples:** `examples/init.pp` for basic usage demonstration

---

*Convention analysis: 2026-04-05*
