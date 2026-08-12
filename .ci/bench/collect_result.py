#!/usr/bin/env python3
"""
Combine criterion output, wireDemo output and run metadata into a single
result.json (schema version 1, see .ci/bench/README.md).

Usage:
  collect_result.py <source> <norm.json> <wiredemo.json> <out.json>

where:
  <source>         "master", "pr" or "pr-backfill"
  <norm.json>      criterion --json output of clash-benchmark-normalization
  <wiredemo.json>  output of run_bittide.sh, or the literal string "stub" to
                   record the wireDemo leg as not yet implemented
  <out.json>       output path

Must be invoked with the benchmarked clash-compiler checkout as the working
directory (commit metadata is read from git). The container image tag, if
any, is read from the BENCH_CONTAINER environment variable.
"""

import datetime
import json
import os
import socket
import subprocess
import sys

NAME_PREFIX = 'normalization of '

WIREDEMO_STUB = {
  'status': 'skipped',
  'skip_reason': 'not yet implemented',
  'bittide_rev': None,
  'runs': [],
}


def run(*cmd):
  res = subprocess.run(cmd, capture_output=True, text=True)
  if res.returncode != 0:
    sys.exit(f"collect_result.py: {' '.join(cmd)} failed: {res.stderr.strip()}")
  return res.stdout.strip()


def criterion_reports(path):
  """Extract the list of reports from criterion's --json output.

  The file holds a JSON array whose last element is the report list; be
  lenient about the exact shape and locate the element that looks like a
  list of reports."""
  with open(path) as f:
    data = json.load(f)
  if isinstance(data, list):
    for element in reversed(data):
      if (isinstance(element, list)
          and all(isinstance(r, dict) and 'reportName' in r for r in element)):
        return element
  sys.exit(f'collect_result.py: unrecognized criterion JSON in {path}')


def normalization(path):
  results = {}
  for report in criterion_reports(path):
    name = report['reportName']
    if name.startswith(NAME_PREFIX):
      name = name[len(NAME_PREFIX):]
    analysis = report['reportAnalysis']
    results[name] = {
      'mean_s': analysis['anMean']['estPoint'],
      'stddev_s': analysis['anStdDev']['estPoint'],
    }
  if not results:
    sys.exit(f'collect_result.py: no benchmark reports found in {path}')
  return results


def cpu_model():
  try:
    with open('/proc/cpuinfo') as f:
      for line in f:
        if line.startswith('model name'):
          return line.split(':', 1)[1].strip()
  except OSError:
    pass
  return 'unknown'


def main():
  if len(sys.argv) != 5:
    sys.exit(__doc__.strip())
  source, norm_path, wiredemo_path, out_path = sys.argv[1:5]
  if source not in ('master', 'pr', 'pr-backfill'):
    sys.exit(f'collect_result.py: bad source {source!r}')

  if wiredemo_path == 'stub':
    wire_demo = WIREDEMO_STUB
  else:
    with open(wiredemo_path) as f:
      wire_demo = json.load(f)

  result = {
    'schema_version': 1,
    'clash_commit': run('git', 'rev-parse', 'HEAD'),
    'parents': run('git', 'rev-list', '--parents', '-n1', 'HEAD').split()[1:],
    'date': datetime.datetime.now(datetime.timezone.utc)
              .isoformat(timespec='seconds'),
    'source': source,
    'machine': {
      'hostname': socket.gethostname(),
      'cpu': cpu_model(),
      'container': os.environ.get('BENCH_CONTAINER'),
    },
    'ghc_version': run('ghc', '--numeric-version'),
    'normalization': normalization(norm_path),
    'wire_demo': wire_demo,
  }

  os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
  with open(out_path, 'w') as f:
    json.dump(result, f, indent=2, sort_keys=True)
    f.write('\n')


if __name__ == '__main__':
  main()
