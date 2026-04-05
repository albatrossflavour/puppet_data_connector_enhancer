# Codebase Structure

**Analysis Date:** 2026-04-05

## Directory Layout

```text
puppet_data_connector_enhancer/
├── manifests/                  # Puppet class declarations
│   ├── init.pp                 # Main class (entry point for all nodes)
│   ├── client.pp               # Private class: all nodes collect CIS score facts
│   └── scm.pp                  # Private class: PE server manages SCM export
├── templates/                  # EPP templates (generate deployed Ruby scripts + systemd units)
│   ├── puppet_data_connector_enhancer.epp  # Main metrics collection script (1028 lines)
│   ├── export_and_download_cis.rb.epp      # SCM CIS export/download script (342 lines)
│   ├── cis_fact.yaml.epp                   # YAML fact file for CIS scores
│   ├── puppet-data-connector-enhancer.service.epp  # systemd service unit
│   └── puppet-data-connector-enhancer.timer.epp    # systemd timer unit
├── lib/
│   └── puppet/
│       └── functions/
│           └── puppet_data_connector_enhancer/
│               └── parse_csv.rb            # Puppet function: CSV parser for CIS data
├── files/                      # Static Grafana dashboard JSON files
│   ├── puppet_status.json
│   ├── puppet_node_detail.json
│   ├── puppet_patching_status.json
│   ├── puppet_patching_detail.json
│   ├── puppet_patching_blocked.json
│   ├── puppet_os_overview.json
│   ├── puppet_restart_overview.json
│   ├── puppet_cis.json
│   └── puppet_dashboards.json
├── data/                       # Hiera module data
│   └── common.yaml             # Default parameter values
├── spec/                       # RSpec tests
│   ├── classes/
│   │   ├── puppet_data_connector_enhancer_spec.rb
│   │   ├── client_spec.rb
│   │   └── scm_spec.rb
│   ├── functions/
│   │   └── parse_csv_spec.rb
│   └── acceptance/
│       └── class_spec.rb
├── examples/
│   └── init.pp                 # Usage example manifest
├── images/                     # Screenshots for README/docs
├── hiera.yaml                  # Module-level Hiera hierarchy config
├── metadata.json               # Puppet Forge module metadata
├── Gemfile                     # Ruby gem dependencies for development/testing
├── Rakefile                    # Rake tasks (PDK-generated)
├── .fixtures.yml               # Spec test fixture modules (stdlib, systemd)
├── .puppet-lint.rc             # puppet-lint configuration
├── .rubocop.yml                # RuboCop Ruby style configuration
└── .rspec                      # RSpec configuration
```

## Directory Purposes

**`manifests/`:**

- Purpose: All Puppet class declarations for the module
- Contains: Three classes following the standard `module::classname` convention
- Key files: `init.pp` (main class), `scm.pp` (PE server role), `client.pp` (all-nodes role)

**`templates/`:**

- Purpose: EPP templates that generate file content at catalog compilation time
- Contains: Ruby script bodies and systemd unit content with `<%= $variable %>` interpolation
- Key files: `puppet_data_connector_enhancer.epp` is the largest file in the repo at 1028 lines

**`lib/puppet/functions/puppet_data_connector_enhancer/`:**

- Purpose: Ruby-backed Puppet functions that run on the Puppet master during compilation
- Contains: `parse_csv.rb` only; namespace matches module name per Puppet autoloading rules
- Key files: `parse_csv.rb`

**`files/`:**

- Purpose: Static files served by the Puppet fileserver (Grafana dashboard definitions)
- Contains: Grafana JSON dashboard exports for all supported dashboard types
- Generated: No. These are hand-crafted or exported from Grafana.
- Committed: Yes

**`data/`:**

- Purpose: Module Hiera data providing parameter defaults
- Contains: `common.yaml` with SCM-related defaults; OS-specific directories would go under `os/`
- Key files: `data/common.yaml`

**`spec/`:**

- Purpose: RSpec unit and acceptance tests
- Contains: Class specs under `spec/classes/`, function specs under `spec/functions/`, acceptance under `spec/acceptance/`

**`examples/`:**

- Purpose: Runnable example manifests for documentation and manual testing
- Contains: `init.pp` showing basic usage patterns

## Key File Locations

**Entry Points:**

- `manifests/init.pp`: Main class; start here to understand the module
- `examples/init.pp`: Usage examples showing parameter combinations

**Configuration:**

- `metadata.json`: Module version, dependencies, supported OS list
- `hiera.yaml`: Module Hiera hierarchy (OS family and common tiers)
- `data/common.yaml`: Default Hiera values for SCM parameters
- `.fixtures.yml`: Test dependencies (stdlib, systemd modules)

**Core Logic:**

- `templates/puppet_data_connector_enhancer.epp`: The deployed metrics collection script
- `templates/export_and_download_cis.rb.epp`: The deployed SCM export script
- `lib/puppet/functions/puppet_data_connector_enhancer/parse_csv.rb`: CSV parsing function

**Testing:**

- `spec/classes/puppet_data_connector_enhancer_spec.rb`: Main class unit tests
- `spec/classes/scm_spec.rb`: SCM subclass unit tests
- `spec/classes/client_spec.rb`: Client subclass unit tests
- `spec/functions/parse_csv_spec.rb`: Function unit tests

## Naming Conventions

**Files:**

- Puppet manifests: `snake_case.pp`, matching the class name after `module::`
- EPP templates: `snake_case.epp`, or `component-name.unit-type.epp` for systemd units
- Ruby functions: `snake_case.rb`, under a namespace directory matching the module name
- Spec files: `<subject>_spec.rb` following RSpec convention

**Directories:**

- Module namespace directory under `lib/puppet/functions/` matches the module name exactly: `puppet_data_connector_enhancer/`

**Classes:**

- Main class: same as module name `puppet_data_connector_enhancer`
- Subclasses: `puppet_data_connector_enhancer::<role>` (e.g., `::scm`, `::client`)

**Parameters:**

- `snake_case` throughout; prefixed by component where needed (e.g., `scm_dir`, `scm_auth`, `scm_timer_interval`)

**Puppet Functions:**

- Namespaced: `puppet_data_connector_enhancer::parse_csv` matching the file path

## Where to Add New Code

**New metric collection type:**

- Edit `templates/puppet_data_connector_enhancer.epp`: add a `collect_<type>` private method on `PrometheusMetricsGenerator` and register it in `generate_metrics`
- Add a corresponding test context in `spec/classes/puppet_data_connector_enhancer_spec.rb`

**New module parameter:**

- Add to the parameter list in `manifests/init.pp`
- Add a default in `data/common.yaml` if the parameter is optional or has a sensible default
- Pass it into the relevant EPP template call within `init.pp`
- Add it to the EPP template signature in `templates/puppet_data_connector_enhancer.epp`
- Add test coverage in `spec/classes/puppet_data_connector_enhancer_spec.rb`

**New Puppet function:**

- Create `lib/puppet/functions/puppet_data_connector_enhancer/<function_name>.rb`
- Add spec at `spec/functions/<function_name>_spec.rb`

**New subclass:**

- Create `manifests/<classname>.pp` using the `puppet_data_connector_enhancer::<classname>` class name
- Include or declare it conditionally from `manifests/init.pp`
- Add spec at `spec/classes/<classname>_spec.rb`

**New Grafana dashboard:**

- Add JSON export to `files/` and document in `DASHBOARDS.md`

## Special Directories

**`.planning/`:**

- Purpose: GSD planning documents (codebase maps, phases, etc.)
- Generated: By GSD commands
- Committed: Yes (planning artefacts)

**`.claude/`:**

- Purpose: Claude/AI assistant context files
- Generated: By Claude Code
- Committed: Yes

**`images/`:**

- Purpose: Screenshots and diagrams for README and documentation
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-05*
