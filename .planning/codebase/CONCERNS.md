# Codebase Concerns

**Analysis Date:** 2026-04-05

## Security Considerations

**SSL certificate verification disabled across all HTTPS calls:**

- Risk: Every HTTPS call in the codebase uses `OpenSSL::SSL::VERIFY_NONE`, meaning
  TLS certificates are never validated. This is present in both the SCM export script
  and the main metrics collector. An attacker with network access could perform a
  man-in-the-middle attack and intercept or manipulate the SCM API token or metrics data.
- Files: `templates/export_and_download_cis.rb.epp` (lines 39, 90, 150, 226),
  `templates/puppet_data_connector_enhancer.epp` (line 170)
- Current mitigation: The SCM script runs as `pe-puppet` with restricted permissions.
  The comment in the metrics template says "disable SSL verification by default" but
  provides no mechanism to override it.
- Recommendations: Add a configurable `ssl_verify` parameter (default true). Use
  `OpenSSL::SSL::VERIFY_PEER` and allow the CA bundle path to be specified. The SCM
  script is particularly risky since it transmits an API bearer token.

**Bearer token rendered as plaintext in deployed script:**

- Risk: The `scm_auth` parameter is typed `Sensitive[String[1]]` in Puppet, which
  prevents it appearing in logs and reports. However the EPP template renders it
  directly into the deployed Ruby script at `${scm_dir}/export_and_download_cis`.
  That file lands on disk readable by `pe-puppet` (mode `0700`), but the token is
  plaintext inside the script body.
- Files: `templates/export_and_download_cis.rb.epp` (line 280),
  `manifests/scm.pp` (lines 53-68)
- Current mitigation: Script mode is `0700`, so only `pe-puppet` can read it.
- Recommendations: Source the token from an environment variable set by the systemd
  unit rather than baking it into the file. This avoids the token persisting in the
  file as plaintext and removes it from Puppet catalog diffs if the token rotates.

## Tech Debt

**`clean_up` uses symbol key to sort a hash returned with string keys:**

- Issue: `list_exports` returns `JSON.parse(response.body)`, which gives string-keyed
  hashes. The `clean_up` function then sorts by `time[:created_at]` (symbol key) rather
  than `time['created_at']` (string key). Ruby returns `nil` for a missing symbol key,
  so all entries sort equal, and cleanup silently fails to order correctly. Old exports
  may not be deleted in the intended order.
- Files: `templates/export_and_download_cis.rb.epp` (line 216)
- Impact: Export retention may not work as expected. Old exports could accumulate on
  the SCM server beyond the configured `scm_export_retention` limit.
- Fix approach: Change `time[:created_at]` to `time['created_at']` on line 216.

**`scm_timer_interval` parameter has weaker validation than `timer_interval`:**

- Issue: `timer_interval` is typed `String[1]` in `init.pp`, but `scm_timer_interval`
  uses `Pattern[/^.+$/]`, which accepts any non-empty string including invalid systemd
  `OnCalendar` expressions. This inconsistency is minor but means bad values only fail
  at systemd level, not at catalog compilation.
- Files: `manifests/init.pp` (lines 113, 126), `manifests/scm.pp` (line 39)
- Impact: Low. A bad value fails when systemd tries to reload the timer unit.
- Fix approach: Align both parameters to the same type. Consider using a more specific
  pattern that validates systemd calendar syntax.

**`process_export` uses `Dir.chdir` and shell `system()` calls:**

- Issue: The `process_export` function uses `Dir.chdir` to change the working directory
  during execution, then calls `system("unzip #{zip_file}")` and
  `system("find . -name \"*.gz\" -exec gzip -d {} \\;")`. Using `Dir.chdir` in a
  multi-threaded context is unsafe. More practically, `unzip` must be present on the
  PE server, which is not declared as a dependency. The `system()` calls also redirect
  to `/dev/null`, swallowing any useful error output.
- Files: `templates/export_and_download_cis.rb.epp` (lines 177-207)
- Impact: If `unzip` is absent the script aborts with no clear error. On RHEL/CentOS
  minimal installs, `unzip` is commonly absent.
- Fix approach: Use Ruby's `Zip` gem (or `rubyzip`) to handle the archive without
  shell dependency. Alternatively, add an explicit package resource for `unzip` in
  `manifests/scm.pp`. Remove `> /dev/null` redirects so errors surface in the journal.

**`last_success_timestamp` is never preserved across failure runs:**

- Issue: When the SCM export fails, the status file is written with
  `last_success_timestamp: nil`. This overwrites the previous success timestamp.
  Prometheus/Grafana consumers of `puppet_scm_export_last_success_timestamp` will see
  the metric disappear after a single failure rather than retaining the last known
  good time.
- Files: `templates/export_and_download_cis.rb.epp` (lines 329-340)
- Impact: Monitoring dashboards lose the "time since last success" signal on any
  transient failure.
- Fix approach: Read the existing status file before writing on failure, and carry
  forward the previous `last_success_timestamp` if present.

**`lookup_in_parameter` lint suppression for `$dropzone` default:**

- Issue: The `$dropzone` parameter default uses `lookup()` directly in the class
  parameter list. This is unconventional and requires the `lint:ignore:lookup_in_parameter`
  suppression. It also creates a hard implicit dependency on `puppet_data_connector`
  being applied first, or the default value kicks in silently without any warning that
  the upstream module is absent.
- Files: `manifests/init.pp` (line 114)
- Impact: If `puppet_data_connector` is not applied, the fallback path
  `/opt/puppetlabs/puppet/prometheus_dropzone` is used with no warning. Metrics are
  silently written to a different location.
- Fix approach: Move the lookup to the class body with an explicit check, or make
  `$dropzone` a required parameter with no default and document it clearly.

## Fragile Areas

**PE-server detection using `$facts['puppet_server'] == $facts['clientcert']`:**

- Files: `manifests/init.pp` (line 148)
- Why fragile: This is the standard idiom for detecting the PE server in Puppet code,
  but it breaks in PE HA configurations where the replica or compiler pools have
  different certnames. SCM collection would then not run on the primary, or could
  incorrectly activate on a compiler.
- Safe modification: Test against `$trusted['certname']` rather than
  `$facts['clientcert']`, and consider documenting that HA configurations need
  explicit `scm_server` targeting.
- Test coverage: The scm_spec.rb tests mock these facts but do not cover HA scenarios.

**Exported resource path collision if certname contains path-unsafe characters:**

- Files: `manifests/scm.pp` (lines 111-128)
- Why fragile: The exported file resource uses
  `/opt/puppetlabs/facter/facts.d/cis_score_${certname}.yaml` as its path. If a
  certname contains characters that are valid in a certname but problematic in a
  filesystem path (unlikely but possible with non-standard setups), this could fail
  silently or create unexpected paths.
- Safe modification: This is low risk for standard PE deployments. Certnames are
  validated as `Stdlib::Fqdn` in the Puppet agent. No action required unless
  non-standard certnames are in use.
- Test coverage: Not tested for edge-case certnames.

**`process_export` leaves orphaned `tmp_dir` on partial failures:**

- Files: `templates/export_and_download_cis.rb.epp` (lines 176-207)
- Why fragile: If `Dir.chdir(tmp_dir)` succeeds but the CSV move fails, the temporary
  directory is never cleaned up. Repeated failures accumulate directories named
  `Summary_Report_TIMESTAMP` in `score_data_dir`, with no automated cleanup.
- Safe modification: Wrap in a `begin/ensure` block and `FileUtils.rm_rf(tmp_dir)` on
  completion or failure.
- Test coverage: No unit or acceptance tests cover partial-failure cleanup paths.

## Missing Critical Features

**No Windows support for the main metrics script or systemd timer:**

- Problem: `manifests/client.pp` handles Windows for the CIS fact path, but the main
  module (`init.pp`) deploys a systemd timer and a Linux Ruby script. Windows is not
  listed in `metadata.json` as a supported OS, but the `client` class silently handles
  Windows paths. This creates an inconsistency where Windows nodes collect CIS facts
  but the enhancement script cannot be deployed there.
- Blocks: No impact for Linux-only deployments. Confusion risk if Windows nodes are
  in scope and someone attempts to apply the full class.

**No `unzip` dependency declared:**

- Problem: The SCM export script requires `unzip` to be present on the PE server.
  This is not declared as a package resource anywhere in the module.
- Files: `manifests/scm.pp`, `templates/export_and_download_cis.rb.epp` (line 183)
- Blocks: Silent failure on PE servers where `unzip` is absent (common on minimal
  RHEL installs).

## OS Support Gaps

**OS support matrix is out of date:**

- Risk: `metadata.json` lists Ubuntu up to 22.04, Rocky Linux only at 8, AlmaLinux
  only at 8, and no RHEL 9/10. Ubuntu 24.04 LTS, Rocky 9, AlmaLinux 9, and RHEL 9
  are all in common use in PE environments as of this analysis.
- Files: `metadata.json` (lines 26-57)
- Impact: Module will still work on these platforms (there is no OS-conditional code
  in the main class), but Puppet will log warnings about unsupported OS, and the
  module cannot be published to the Forge with these gaps without user-visible warnings.
- Fix approach: Add missing OS versions to the `operatingsystem_support` array and
  run the unit test matrix against them.

## Test Coverage Gaps

**Acceptance test suite references `spec_helper_acceptance` which has no corresponding file:**

- What is not tested: The acceptance tests in `spec/acceptance/class_spec.rb` require
  `spec_helper_acceptance`, but there is no such file in `spec/`. These tests cannot
  run without a Litmus environment configured externally.
- Files: `spec/acceptance/class_spec.rb` (line 3)
- Risk: CI systems running the test suite will skip or fail acceptance tests silently
  unless Litmus is configured. There is no obvious CI pipeline file in the repo.
- Priority: Medium

**`parse_csv` duplicate-node behaviour is undocumented and silently keeps last occurrence:**

- What is not tested: The spec tests confirm that the last occurrence wins
  (`spec/functions/parse_csv_spec.rb` lines 284-291), but this behaviour is not
  documented in the function's YARD comments. If the SCM produces duplicate rows
  (e.g., a node scanned twice), the earlier result is silently discarded.
- Files: `lib/puppet/functions/puppet_data_connector_enhancer/parse_csv.rb`
- Risk: Low. But worth documenting explicitly so the behaviour is intentional rather
  than accidental.
- Priority: Low

**No tests for the `collect_infra_assistant_tokens` method using a non-array response:**

- What is not tested: `collect_infra_assistant_tokens` in the metrics template calls
  `fetch_json_from_puppetdb` against the Infra Assistant endpoint and then calls
  `tokens.dig(...)` on the result. The method initialises `tokens` with `|| []` but
  the endpoint returns an object/hash, not an array. Passing an empty array to `dig`
  is harmless, but the logic silently falls back to zero counts for all token types
  when the service is absent rather than raising an error.
- Files: `templates/puppet_data_connector_enhancer.epp` (lines 397-425)
- Risk: Low. Zero is a valid sentinel for missing data.
- Priority: Low

---

*Concerns audit: 2026-04-05*
