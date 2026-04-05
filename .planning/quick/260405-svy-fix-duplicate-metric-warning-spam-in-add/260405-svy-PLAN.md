---
phase: quick
plan: 260405-svy
type: execute
wave: 1
depends_on: []
files_modified:
  - templates/puppet_data_connector_enhancer.epp
autonomous: true
must_haves:
  truths:
    - "Duplicate metric dedup in add_metric logs at debug level, not warn"
    - "When a custom metric has no labels and returns multiple rows, a single warn-level message explains why only the first value was used"
  artifacts:
    - path: "templates/puppet_data_connector_enhancer.epp"
      provides: "Fixed log levels for dedup and missing-labels guidance"
      contains: "@logger.debug.*Duplicate metric detected"
  key_links:
    - from: "collect_single_custom_metric"
      to: "add_metric"
      via: "rows.each loop calls add_metric, dedup silently drops extras"
      pattern: "add_metric\\(name, labels, value\\)"
---

<objective>
Fix duplicate metric warning spam in the custom metrics pipeline.

Purpose: When a custom metric has no labels but returns multiple PuppetDB rows,
add_metric fires a warn-level "Duplicate metric detected" message for every row
after the first. This floods the logs with expected-behaviour noise. The fix
downgrades the dedup message to debug and adds a single, actionable warning in
collect_single_custom_metric telling the user to add labels.

Output: Updated `templates/puppet_data_connector_enhancer.epp` with corrected
log levels.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@templates/puppet_data_connector_enhancer.epp (lines 222-242: add_metric method, lines 1105-1132: collect_single_custom_metric method)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Downgrade add_metric dedup log and add missing-labels warning</name>
  <files>templates/puppet_data_connector_enhancer.epp</files>
  <action>
Two changes in templates/puppet_data_connector_enhancer.epp:

1. Line 236 — In the `add_metric` method, change:
   `@logger.warn("Duplicate metric detected: #{metric_key}")`
   to:
   `@logger.debug("Duplicate metric detected: #{metric_key}")`

   Rationale: deduplication is the formatter doing its job, not a warning-worthy event.

2. In `collect_single_custom_metric`, after the `rows.each` loop (after line 1119) and
   before the existing debug log on line 1121, insert a conditional warning block:

   ```ruby
   if labels_map.empty? && rows.length > 1
     @logger.warn("Custom metric '#{name}' returned #{rows.length} rows but has no labels defined — only the first row's value was used. Consider adding labels to differentiate rows.")
   end
   ```

   This gives the user a single actionable message instead of N duplicate warnings.
  </action>
  <verify>
    <automated>cd /Users/tgreen/dev/puppet_data_connector_enhancer && grep -n 'logger.debug.*Duplicate metric detected' templates/puppet_data_connector_enhancer.epp && grep -n 'logger.warn.*returned.*rows but has no labels' templates/puppet_data_connector_enhancer.epp && ! grep -n 'logger.warn.*Duplicate metric detected' templates/puppet_data_connector_enhancer.epp</automated>
  </verify>
  <done>
    - add_metric logs duplicate detection at debug level, not warn
    - collect_single_custom_metric emits a single warn when labels_map is empty and rows.length > 1
    - No warn-level "Duplicate metric detected" messages remain
  </done>
</task>

</tasks>

<verification>
- `grep -c 'logger.warn.*Duplicate' templates/puppet_data_connector_enhancer.epp` returns 0
- `grep -c 'logger.debug.*Duplicate' templates/puppet_data_connector_enhancer.epp` returns 1
- `grep -c 'no labels defined' templates/puppet_data_connector_enhancer.epp` returns 1
- Ruby syntax check: `ruby -c <(sed -n '1,5p' templates/puppet_data_connector_enhancer.epp)` — full syntax check not feasible on EPP, but the changes are single-line edits with no structural risk
</verification>

<success_criteria>
A custom metric with no labels returning 32 PuppetDB rows produces exactly one
warn-level log line ("returned 32 rows but has no labels defined") instead of 31
warn-level "Duplicate metric detected" lines.
</success_criteria>

<output>
After completion, create `.planning/quick/260405-svy-fix-duplicate-metric-warning-spam-in-add/260405-svy-SUMMARY.md`
</output>
