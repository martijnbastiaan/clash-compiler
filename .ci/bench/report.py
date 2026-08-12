#!/usr/bin/env python3
"""
Render the Markdown benchmark report for the sticky PR comment.

Usage:
  report.py <pr_result.json> <baseline.json> [<baseline_result.json>]

Arguments:
  pr_result.json        result of the PR benchmark run
  baseline.json         output of baseline.py
  baseline_result.json  result of a backfill run, when baseline.py
                        requested one

The report goes to stdout. The input files cross a trust boundary (they
are artifacts from a job that ran PR code). The script validates their
shape first and never gives their content to a shell.

Highlight rule: mark a row when |delta| > 2% and |mean difference| is
more than the sum of the standard deviations.
"""

import json
import os
import sys

HIGHLIGHT_PCT = 2.0


def fail(msg):
  sys.exit(f'report.py: {msg}')


def validate(result, path):
  """Check the schema-v1 shape of a result file."""
  if not isinstance(result, dict):
    fail(f'{path}: not an object')
  if result.get('schema_version') != 1:
    fail(f'{path}: unsupported schema_version')
  for key in ('clash_commit', 'machine', 'ghc_version', 'normalization',
              'wire_demo'):
    if key not in result:
      fail(f'{path}: missing key {key!r}')
  if not isinstance(result['normalization'], dict):
    fail(f'{path}: normalization is not an object')
  for name, row in result['normalization'].items():
    if not (isinstance(row, dict)
            and isinstance(row.get('mean_s'), (int, float))
            and isinstance(row.get('stddev_s'), (int, float))):
      fail(f'{path}: bad normalization row {name!r}')
  if not isinstance(result['machine'], dict):
    fail(f'{path}: machine is not an object')
  wire_demo = result['wire_demo']
  if not (isinstance(wire_demo, dict)
          and wire_demo.get('status') in ('ok', 'skipped')):
    fail(f'{path}: bad wire_demo')
  return result


def load(path):
  try:
    with open(path) as f:
      return json.load(f)
  except (OSError, json.JSONDecodeError) as e:
    fail(f'cannot read {path}: {e}')


def fmt_s(seconds):
  if seconds < 1:
    return f'{seconds * 1000:.1f} ms'
  return f'{seconds:.2f} s'


def fmt_cell(row):
  return f"{fmt_s(row['mean_s'])} ± {fmt_s(row['stddev_s'])}"


def delta_cell(base_row, pr_row):
  base, pr = base_row['mean_s'], pr_row['mean_s']
  if base <= 0:
    return 'n/a'
  pct = (pr - base) / base * 100
  significant = (abs(pct) > HIGHLIGHT_PCT
                 and abs(pr - base) > base_row['stddev_s'] + pr_row['stddev_s'])
  text = f'{pct:+.1f}%'
  if significant:
    icon = '🔴' if pct > 0 else '🟢'
    return f'{icon} **{text}**'
  return text


def wire_demo_rows(baseline_wd, pr_wd):
  """Render wireDemo table rows. Phase 3 fills these with real data."""
  rows = []
  if pr_wd['status'] == 'skipped':
    reason = pr_wd.get('skip_reason') or 'unknown reason'
    rows.append(f'| wireDemo | — | skipped: {reason} | — |')
    return rows
  base_runs = baseline_wd['runs'] if (
    baseline_wd and baseline_wd.get('status') == 'ok'
    and baseline_wd.get('bittide_rev') == pr_wd.get('bittide_rev')) else None
  for metric, label in (('normalization_s', 'wireDemo normalization'),
                        ('total_s', 'wireDemo total')):
    pr_val = pr_wd['runs'][0][metric]
    if base_runs:
      base_val = base_runs[0][metric]
      # A single run has no spread. Use the 2% rule alone.
      base_row = {'mean_s': base_val, 'stddev_s': 0.0}
      pr_row = {'mean_s': pr_val, 'stddev_s': 0.0}
      rows.append(f'| {label} | {fmt_s(base_val)} | {fmt_s(pr_val)} '
                  f'| {delta_cell(base_row, pr_row)} |')
    else:
      rows.append(f'| {label} | no baseline | {fmt_s(pr_val)} | — |')
  return rows


def main():
  if len(sys.argv) not in (3, 4):
    sys.exit(__doc__.strip())
  pr_result = validate(load(sys.argv[1]), sys.argv[1])
  baseline_info = load(sys.argv[2])
  if len(sys.argv) == 4:
    baseline = validate(load(sys.argv[3]), sys.argv[3])
    baseline_note = 'merge base (benchmarked in this run)'
  elif baseline_info.get('result'):
    baseline = validate(baseline_info['result'], sys.argv[2])
    distance = baseline_info.get('distance', 0)
    behind = (f', {distance} commits behind the merge base'
              if distance else '')
    baseline_note = f"`{baseline_info['baseline_sha'][:7]}`{behind}"
  else:
    baseline = None
    baseline_note = 'none found'

  # Numbers from different machines do not compare. Drop the baseline.
  if baseline and (baseline['machine'].get('hostname')
                   != pr_result['machine'].get('hostname')):
    baseline = None
    baseline_note = 'discarded: baseline is from a different machine'

  lines = ['| Benchmark | Baseline | This PR | Δ |',
           '|---|---|---|---|']
  base_norm = baseline['normalization'] if baseline else {}
  for name in sorted(pr_result['normalization']):
    pr_row = pr_result['normalization'][name]
    base_row = base_norm.get(name)
    if base_row:
      lines.append(f'| `{name}` | {fmt_cell(base_row)} | {fmt_cell(pr_row)} '
                   f'| {delta_cell(base_row, pr_row)} |')
    else:
      lines.append(f'| `{name}` | no baseline | {fmt_cell(pr_row)} | — |')

  # The wireDemo columns can use a separate, older baseline when the
  # main baseline has no usable wire_demo leg (see baseline.py).
  wd_base = baseline['wire_demo'] if baseline else None
  wd_note = None
  split = baseline_info.get('wire_demo_baseline')
  if (split and pr_result['wire_demo']['status'] == 'ok'
      and not (wd_base and wd_base.get('status') == 'ok'
               and wd_base.get('bittide_rev')
                   == pr_result['wire_demo'].get('bittide_rev'))):
    split = validate(split, 'wire_demo_baseline')
    if (split['machine'].get('hostname')
        == pr_result['machine'].get('hostname')):
      wd_base = split['wire_demo']
      wd_note = (f"wireDemo baseline: `{split['clash_commit'][:7]}` "
                 f'(older result with a matching bittide-hardware '
                 f'revision).')
  lines += wire_demo_rows(wd_base, pr_result['wire_demo'])

  machine = pr_result['machine']
  footer = [
    '',
    f"Baseline: {baseline_note}. Machine: `{machine.get('hostname')}` "
    f"({machine.get('cpu')}). GHC {pr_result['ghc_version']}.",
  ]
  if wd_note:
    footer.append(wd_note)
  bittide_rev = pr_result['wire_demo'].get('bittide_rev')
  if bittide_rev:
    footer.append(f'bittide-hardware: `{bittide_rev[:7]}`.')
  run_id = os.environ.get('GITHUB_RUN_ID')
  if run_id:
    server = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
    repo = os.environ.get('GITHUB_REPOSITORY', '')
    footer.append(f'[Workflow run]({server}/{repo}/actions/runs/{run_id}).')

  print('\n'.join(lines + footer))


if __name__ == '__main__':
  main()
