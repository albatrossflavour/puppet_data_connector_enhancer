---
phase: 02-custom-metrics-engine
plan: 02
subsystem: cli
tags: [puppet, ruby, epp, cli, optparse, puppetdb, prometheus, yaml]

requires:
  - phase: 02-custom-metrics-engine
    provides: Validation engine with constants (BUILTIN_METRIC_PREFIXES, VALID_ENDPOINT_TYPES, etc.) and methods (validate_single_definition, validate_pql_query, sanitise_pql_timestamp)

provides:
  - CLI metric builder tool for guided custom metric definition creation
  - Interactive and flag-based input modes for metric definitions
  - Placeholder and live PuppetDB preview of Prometheus exposition output
  - YAML config file writing with duplicate detection

affects: [03-dashboards-and-self-monitoring]

tech-stack:
  added: []
  patterns:
    - "CLI tool deployed as EPP-generated Ruby script alongside main collector"
    - "Shared validation constants duplicated at EPP compile time for single source of truth"
    - "OptionParser with interactive fallback when required flags missing"

key-files:
  created:
    - templates/puppet_custom_metric_builder.epp
  modified:
    - manifests/init.pp

key-decisions:
  - "Validation constants and methods duplicated in CLI EPP template rather than shared module, since both are EPP-generated and identical at deploy time"
  - "Interactive mode triggers when any required flag (name, endpoint, type, help) is missing"
  - "Live preview fetches 3 sample rows from PuppetDB with SSL client cert auth"

patterns-established:
  - "CLI tool pattern: EPP template generating standalone Ruby script with PE shebang"
  - "Puppet file resource pattern for CLI tools: same ensure, ownership, permissions as main script"

requirements-completed: [CUST-01]

duration: 4min
completed: 2026-04-05
---

# Phase 02 Plan 02: CLI Metric Builder Tool Summary

**CLI tool with interactive prompts and flag mode for building custom metric YAML definitions, with shared validation logic and live PuppetDB preview**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-05T09:20:39Z
- **Completed:** 2026-04-05T09:24:27Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- CLI metric builder EPP template generating a complete Ruby script with CustomMetricBuilder class
- Interactive mode prompting for each field with inline validation and re-prompting on errors
- Flag mode with OptionParser supporting all metric definition fields plus --preview-only and --live-preview
- Placeholder preview showing HELP/TYPE headers and metric lines with angle-bracket placeholders
- Live preview querying PuppetDB via SSL client cert auth and rendering actual data
- YAML config writing with existing file loading and duplicate name detection
- Validation logic identical to runtime engine (same constants, same methods, same error messages)
- Puppet file resource deploying CLI tool at ${scm_dir}/puppet_custom_metric_builder

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CLI metric builder EPP template** - `65aeb81` (feat)
2. **Task 2: Deploy CLI tool via Puppet file resource** - `d244136` (feat)

## Files Created/Modified

- `templates/puppet_custom_metric_builder.epp` - EPP template generating the CLI Ruby script with CustomMetricBuilder class
- `manifests/init.pp` - Added file resource for CLI tool deployment alongside main script

## Decisions Made

- Validation constants and methods are duplicated in the CLI EPP template rather than extracted to a shared Ruby library. Both files are EPP-generated at Puppet compile time, so the constants are guaranteed identical at deployment. This avoids adding a shared Ruby lib dependency to the module structure.
- Interactive mode activates when any of the four required flags (name, endpoint, type, help) is missing. This means partial flag usage falls through to interactive mode rather than failing.
- Live preview fetches 3 sample rows to keep output readable while demonstrating real data. Uses the same SSL cert paths as the main collector script.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `bundle exec rake validate` failed due to missing gems in this worktree. Fell back to `puppet parser validate` and `puppet epp validate` which both passed cleanly.

## Next Phase Readiness

- CLI tool ready for deployment alongside the main metrics collector
- Validation logic shared between CLI and runtime engine ensures consistent behaviour
- Ready for Phase 3 dashboard generation work

## Self-Check: PASSED

All files and commits verified.

---
*Phase: 02-custom-metrics-engine*
*Completed: 2026-04-05*
