#!/usr/bin/env python3
"""
Create or update the sticky benchmark comment on a PR.

Usage:
  comment.py <pr_number> queued            <head_sha>
  comment.py <pr_number> awaiting-approval <head_sha>
  comment.py <pr_number> running           <head_sha>
  comment.py <pr_number> done              <head_sha> <report_md_file>
  comment.py <pr_number> failed            <head_sha> <run_url>

Give full 40-character shas. The comment holds its state in an HTML
comment. Transitions are guarded: a newer event wins, an old job cannot
overwrite it. See the state table in .ci/bench/README.md.

Environment: GITHUB_TOKEN, GITHUB_REPOSITORY, and for the run link
GITHUB_SERVER_URL, GITHUB_RUN_ID. GITHUB_API_URL is optional.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

MARKER = '<!-- clash-benchmark-bot -->'
REPORT_MARKER = '<!-- report -->'
STATE_RE = re.compile(r'<!-- state: (\{.*?\}) -->')
LINK_NEXT_RE = re.compile(r'<([^>]+)>; rel="next"')

API = os.environ.get('GITHUB_API_URL', 'https://api.github.com')


def short(sha):
  return sha[:7]


def run_url():
  server = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
  repo = os.environ['GITHUB_REPOSITORY']
  run_id = os.environ.get('GITHUB_RUN_ID')
  if run_id is None:
    return None
  return f'{server}/{repo}/actions/runs/{run_id}'


def api(method, url, body=None):
  """One GitHub API request. Returns (parsed body, next-page url)."""
  data = json.dumps(body).encode() if body is not None else None
  req = urllib.request.Request(url, data=data, method=method, headers={
    'Authorization': f"Bearer {os.environ['GITHUB_TOKEN']}",
    'Accept': 'application/vnd.github+json',
    'Content-Type': 'application/json',
  })
  try:
    with urllib.request.urlopen(req) as resp:
      match = LINK_NEXT_RE.search(resp.headers.get('Link') or '')
      return json.load(resp), match.group(1) if match else None
  except urllib.error.HTTPError as e:
    sys.exit(f'comment.py: {method} {url} failed: {e.code} {e.read().decode()}')


def find_comment(pr):
  """Return the bot comment of the PR, or None."""
  repo = os.environ['GITHUB_REPOSITORY']
  url = f'{API}/repos/{repo}/issues/{pr}/comments?per_page=100'
  while url:
    comments, url = api('GET', url)
    for comment in comments:
      if MARKER in comment['body']:
        return comment
  return None


def parse_state(body):
  """Return the state dict from a comment body, or None.

  Treat a missing or unreadable state as no state. Then the next
  transition writes a fresh comment body, and the comment self-heals."""
  match = STATE_RE.search(body)
  if not match:
    return None
  try:
    state = json.loads(match.group(1))
  except json.JSONDecodeError:
    return None
  if not isinstance(state, dict) or 'head_sha' not in state:
    return None
  return state


def extract_report(body):
  if REPORT_MARKER not in body:
    return None
  report = body.split(REPORT_MARKER, 1)[1]
  # Drop a rendered stale banner. render() adds the banner again when
  # it applies. Without this step, every render stacks one more banner.
  lines = [l for l in report.split('\n') if not l.startswith('> ⚠️ **Stale**')]
  return '\n'.join(lines).strip('\n')


def status_line(state):
  sha = short(state['head_sha'])
  status = state['status']
  url = state.get('run_url')
  log = f' ([log]({url}))' if url else ''
  if status == 'queued':
    return f'⏳ Benchmark **queued** for `{sha}`.'
  if status == 'awaiting-approval':
    return (f'🔒 `{sha}` was pushed from a fork and needs approval. '
            f'Maintainer: comment `@kloonbot run_benchmark {sha}` to '
            f'benchmark it.')
  if status == 'running':
    return f'🏃 Benchmark **running** for `{sha}`{log}.'
  if status == 'done':
    return f'✅ Benchmark **done** for `{sha}`{log}.'
  if status == 'failed':
    return f'❌ Benchmark **failed** for `{sha}`{log}.'
  sys.exit(f'comment.py: unknown status {status!r}')


def render(state, report):
  lines = [
    MARKER,
    f'<!-- state: {json.dumps(state, sort_keys=True)} -->',
    '### Clash benchmark bot',
    status_line(state),
  ]
  if report:
    lines += ['', '---', REPORT_MARKER]
    if state.get('report_sha') and state['report_sha'] != state['head_sha']:
      lines += [f"> ⚠️ **Stale**: the report below is for "
                f"`{short(state['report_sha'])}`.", '']
    lines += [report.rstrip('\n')]
  return '\n'.join(lines) + '\n'


def transition(cmd, sha, old, report, extra):
  """Compute the new state, or None when this event is superseded."""
  if cmd in ('queued', 'awaiting-approval'):
    # A new head always supersedes. Keep the old report; render() marks
    # it stale when it is for another sha.
    return {'head_sha': sha, 'status': cmd,
            'report_sha': old.get('report_sha') if old else None,
            'run_url': run_url()}, report
  if cmd == 'running':
    # Promote queued to running only for the same sha. Otherwise a newer
    # event owns the comment; do not touch it.
    if not old or old['status'] != 'queued' or old['head_sha'] != sha:
      return None, None
    return dict(old, status='running', run_url=run_url()), report
  if cmd == 'done':
    new_report = open(extra).read()
    if old and old['head_sha'] != sha:
      # The head moved while we benchmarked. Publish the report, but keep
      # the newer status. render() adds the stale banner.
      return dict(old, report_sha=sha), new_report
    return {'head_sha': sha, 'status': 'done', 'report_sha': sha,
            'run_url': run_url()}, new_report
  if cmd == 'failed':
    if old and old['head_sha'] != sha:
      return None, None
    return {'head_sha': sha, 'status': 'failed',
            'report_sha': old.get('report_sha') if old else None,
            'run_url': extra}, report
  sys.exit(f'comment.py: unknown command {cmd!r}')


def main():
  if len(sys.argv) < 4:
    sys.exit(__doc__.strip())
  pr, cmd, sha = sys.argv[1], sys.argv[2], sys.argv[3]
  extra = sys.argv[4] if len(sys.argv) > 4 else None
  if cmd in ('done', 'failed') and extra is None:
    sys.exit(__doc__.strip())

  comment = find_comment(pr)
  old = parse_state(comment['body']) if comment else None
  report = extract_report(comment['body']) if comment else None

  new, report = transition(cmd, sha, old, report, extra)
  if new is None:
    print(f'comment.py: {cmd} for {short(sha)} is superseded, not editing')
    return

  body = render(new, report)
  repo = os.environ['GITHUB_REPOSITORY']
  if comment:
    api('PATCH', f"{API}/repos/{repo}/issues/comments/{comment['id']}",
        {'body': body})
  else:
    api('POST', f'{API}/repos/{repo}/issues/{pr}/comments', {'body': body})
  print(f'comment.py: set {new["status"]} for {short(sha)}')


if __name__ == '__main__':
  main()
