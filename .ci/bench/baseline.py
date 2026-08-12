#!/usr/bin/env python3
"""
Find a baseline result for a benchmark run.

Usage:
  baseline.py <clash_repo_dir> <results_ref> <merge_base_sha> <out_json>

The script walks the first-parent history from the merge base, with a
budget of 50 commits. The first commit that has a result file on the
results ref is the baseline. When no commit has a result, the bench job
must benchmark the merge base itself ("backfill").

The wireDemo columns need a baseline with wire_demo status "ok" and the
bittide_rev that is pinned now (.ci/bench/bittide-rev). When the main
baseline does not qualify, the walk continues inside the same budget
and a separate wire-demo baseline is reported.

Output (out_json):
  merge_base           the given merge base sha
  baseline_sha         sha of the baseline result, or null
  distance             number of commits between merge base and baseline
  backfill_sha         sha the bench job must benchmark first, or null
  result               the baseline result.json content, when found
  wire_demo_baseline   a result with a usable wire_demo leg, or null
                       (null when the main baseline already qualifies)
"""

import json
import os
import subprocess
import sys

BUDGET = 50


def git(repo, *args):
  return subprocess.run(['git', '-C', repo, *args],
                        capture_output=True, text=True)


def wire_demo_ok(result, bittide_rev):
  wire_demo = result.get('wire_demo') or {}
  return (wire_demo.get('status') == 'ok'
          and wire_demo.get('bittide_rev') == bittide_rev)


def main():
  if len(sys.argv) != 5:
    sys.exit(__doc__.strip())
  repo, ref, base, out_path = sys.argv[1:5]

  script_dir = os.path.dirname(os.path.abspath(__file__))
  with open(os.path.join(script_dir, 'bittide-rev')) as f:
    bittide_rev = f.read().strip()

  out = {'merge_base': base, 'baseline_sha': None, 'distance': None,
         'backfill_sha': base, 'result': None, 'wire_demo_baseline': None}

  # The results branch does not exist on first contact. Then backfill.
  if git(repo, 'rev-parse', '--verify', '--quiet', ref).returncode == 0:
    rev_list = git(repo, 'rev-list', '--first-parent',
                   f'--max-count={BUDGET}', base)
    if rev_list.returncode != 0:
      sys.exit(f'baseline.py: rev-list failed: {rev_list.stderr.strip()}')
    for distance, sha in enumerate(rev_list.stdout.split()):
      show = git(repo, 'show', f'{ref}:results/{sha[:2]}/{sha}.json')
      if show.returncode != 0:
        continue
      result = json.loads(show.stdout)
      if out['baseline_sha'] is None:
        out.update(baseline_sha=sha, distance=distance, backfill_sha=None,
                   result=result)
        if wire_demo_ok(result, bittide_rev):
          break
      elif wire_demo_ok(result, bittide_rev):
        # The main baseline has no usable wire_demo leg. Take the first
        # older result that has one, for the wireDemo columns only.
        out['wire_demo_baseline'] = result
        break

  with open(out_path, 'w') as f:
    json.dump(out, f, indent=2)
    f.write('\n')

  if out['baseline_sha']:
    print(f"baseline.py: baseline {out['baseline_sha'][:7]} "
          f"({out['distance']} commits behind merge base)")
  else:
    print(f'baseline.py: no baseline in the last {BUDGET} first-parent '
          f'commits; backfill {base[:7]}')


if __name__ == '__main__':
  main()
