#!/usr/bin/env bash
# Benchmark a range of master commits, oldest first.
#
# Usage: backfill.sh <from_sha> <to_sha>
#
# Run this script in a workspace that has a full clash-compiler clone in
# ./clash-compiler. The script benchmarks each first-parent commit from
# <from_sha> up to and including <to_sha>, and pushes each result at
# once. The loop is safe to run again:
#
#   - It skips a commit when the results branch already has its result
#     with wire_demo.status "ok".
#   - It benchmarks a commit again when the stored result has a skipped
#     wireDemo leg, and replaces that result.
#
# One failed commit does not stop the loop. The script prints a summary
# at the end and exits with code 1 when one or more commits failed.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <from_sha> <to_sha>" >&2
  exit 1
fi

script_dir=$(dirname "$(realpath "$0")")
repo=clash-compiler
results_ref=refs/remotes/origin/benchmark-results

if [[ ! -d "${repo}/.git" ]]; then
  echo "backfill.sh: no clash-compiler clone in the working directory" >&2
  exit 1
fi
mkdir -p out

fetch_results() {
  git -C "${repo}" fetch -q origin \
    "+benchmark-results:${results_ref}" || true
}

stored_wire_demo_status() {
  # Print the wire_demo status of the stored result for a sha, or
  # "none" when there is no result.
  git -C "${repo}" show "${results_ref}:results/${1:0:2}/${1}.json" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["wire_demo"]["status"])' \
    2>/dev/null || echo "none"
}

from=$(git -C "${repo}" rev-parse --verify "$1^{commit}")
to=$(git -C "${repo}" rev-parse --verify "$2^{commit}")
commits=$(git -C "${repo}" rev-list --first-parent --reverse "${from}^..${to}")
total=$(echo "${commits}" | wc -w)

declare -a done_ok=() done_skipped=() already=() failed=()
n=0
for sha in ${commits}; do
  n=$((n + 1))
  short=${sha:0:7}
  echo "=== backfill.sh: [${n}/${total}] ${sha}"

  # Another run can push results while this loop is busy. Fetch again
  # before each decision.
  fetch_results
  if [[ "$(stored_wire_demo_status "${sha}")" == "ok" ]]; then
    echo "backfill.sh: complete result exists; skip"
    already+=("${sha}")
    continue
  fi

  if (
    set -euo pipefail
    cd "${repo}"
    git checkout -qf "${sha}"
    # Keep the build artifacts: the commits are adjacent, and cabal
    # rebuilds incrementally.
    git clean -dfxq -e dist-newstyle -e '.ghc.environment.*'
    "${script_dir}/run_clash_benchmarks.sh" "../out/norm-${short}.json"
    "${script_dir}/run_bittide.sh" "../out/wiredemo-${short}.json"
    "${script_dir}/collect_result.py" master \
      "../out/norm-${short}.json" "../out/wiredemo-${short}.json" \
      "../out/result-${short}.json"
    "${script_dir}/push_result.sh" --replace-skipped "../out/result-${short}.json"
  ); then
    status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' \
      "out/wiredemo-${short}.json")
    if [[ "${status}" == "ok" ]]; then
      done_ok+=("${sha}")
      # The logs of a good commit have no value. Remove them to keep
      # the artifact small.
      rm -f "out/wiredemo-${short}-build.log" "out/wiredemo-${short}-run.log"
    else
      done_skipped+=("${sha}")
    fi
  else
    echo "backfill.sh: ${sha} failed; continue with the next commit" >&2
    failed+=("${sha}")
  fi
done

echo "=== backfill.sh: summary"
echo "ok:                ${#done_ok[@]}"
echo "wireDemo skipped:  ${#done_skipped[@]} ${done_skipped[*]:-}"
echo "already complete:  ${#already[@]}"
echo "failed:            ${#failed[@]} ${failed[*]:-}"

if [[ ${#failed[@]} -gt 0 ]]; then
  exit 1
fi
