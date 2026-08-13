#!/usr/bin/env bash
# Commit one result.json to the benchmark-results branch.
#
# Usage: push_result.sh [--replace-skipped] <result.json>
#
# Run this script in a clash-compiler clone that has an authenticated origin
# remote (for example, an actions/checkout workspace). The script writes the
# result to results/<sha[0:2]>/<full-sha>.json. If the push is rejected, the
# script fetches the branch again and retries, with three attempts maximum.
# An existing identical result is a success. An existing different result is
# an error. With --replace-skipped, an existing result that has
# wire_demo.status == "skipped" is replaced instead (backfill runs upgrade
# earlier incomplete results this way).

set -euo pipefail

replace_skipped=0
if [[ "${1:-}" == "--replace-skipped" ]]; then
  replace_skipped=1
  shift
fi

if [[ $# -ne 1 ]]; then
  echo "usage: $0 [--replace-skipped] <result.json>" >&2
  exit 1
fi

result=$(realpath "$1")
sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["clash_commit"])' "${result}")
rel="results/${sha:0:2}/${sha}.json"

wt=$(mktemp -d)
cleanup() {
  git worktree remove --force "${wt}" 2>/dev/null || true
  rm -rf "${wt}"
}
trap cleanup EXIT

for attempt in 1 2 3; do
  git fetch origin benchmark-results
  git worktree remove --force "${wt}" 2>/dev/null || true
  git worktree add --detach "${wt}" FETCH_HEAD

  if [[ -f "${wt}/${rel}" ]]; then
    if cmp -s "${wt}/${rel}" "${result}"; then
      echo "push_result.sh: identical result for ${sha} already present"
      exit 0
    fi
    old_status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["wire_demo"]["status"])' "${wt}/${rel}")
    if [[ ${replace_skipped} -eq 1 && "${old_status}" == "skipped" ]]; then
      echo "push_result.sh: replacing result for ${sha} (wire_demo was skipped)"
    else
      echo "push_result.sh: different result for ${sha} already present; refusing to overwrite" >&2
      exit 1
    fi
  fi

  mkdir -p "${wt}/$(dirname "${rel}")"
  cp "${result}" "${wt}/${rel}"
  git -C "${wt}" add "${rel}"
  git -C "${wt}" \
    -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -q -m "Add benchmark result for ${sha}"

  if git -C "${wt}" push origin HEAD:refs/heads/benchmark-results; then
    echo "push_result.sh: pushed ${rel}"
    exit 0
  fi

  echo "push_result.sh: push rejected, retrying (attempt ${attempt}/3)" >&2
  sleep "${attempt}"
done

echo "push_result.sh: giving up after 3 attempts" >&2
exit 1
