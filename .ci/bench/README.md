# Clash benchmark bot

This directory holds the scripts of the benchmark bot. Two workflows use
them:

- `.github/workflows/benchmark-master.yml` benchmarks each merge to
  master and stores the result on the orphan `benchmark-results` branch.
- `.github/workflows/benchmark-pr.yml` benchmarks PRs that have the
  `performance` label and keeps one live sticky comment on the PR.

## What a benchmark run measures

1. **In-repo normalization suite**: `run_clash_benchmarks.sh` runs
   `clash-benchmark-normalization` through criterion. Criterion reports
   the mean time and the standard deviation per source file.
2. **wireDemo**: `run_bittide.sh` builds bittide-hardware against the
   clash-compiler checkout under test. It then generates HDL for
   `Bittide.Instances.Hitl.WireDemo.wireDemoTest` one time, and parses
   the `Clash: ... took` lines. The headline metric is the
   normalization time. When bittide-hardware does not build against the
   checkout, the result records the wireDemo leg as `skipped`. That is
   an accepted loss.

`collect_result.py` merges both outputs and the run metadata into one
`result.json` (schema version 1, see the example below). `push_result.sh`
commits it to the `benchmark-results` branch as
`results/<sha[0:2]>/<full-sha>.json`.

```json
{
  "schema_version": 1,
  "clash_commit": "<sha>", "parents": ["<sha>"],
  "date": "...", "source": "master" | "pr" | "pr-backfill",
  "machine": {"hostname": "...", "cpu": "...", "container": "..."},
  "ghc_version": "9.10.3",
  "normalization": {"examples/FIR.hs": {"mean_s": 1.234, "stddev_s": 0.011}},
  "wire_demo": {
    "status": "ok" | "skipped", "skip_reason": null,
    "bittide_rev": "<sha>",
    "runs": [{"normalization_s": 312.4, "netlist_s": 95.1, "total_s": 490.2}]
  }
}
```

## PR flow

The sticky comment moves through these states:

| Event | Transition |
|---|---|
| `performance` label added, trusted push, or `run_benchmark` dispatch | → `queued`; an old report stays and gets a stale banner |
| bench job starts, head sha unchanged | `queued` → `running` |
| report success | → `done`, report replaced |
| bench or report failure | → `failed` + run link; old report stays |
| push from an external fork | → `awaiting-approval` |

A maintainer approves an external-fork commit with a PR comment:

    @kloonbot run_benchmark <sha>

The sha must be the current PR head. Kloonbot then dispatches
`benchmark-pr.yml` with that exact sha.

Baselines come from `baseline.py`: it walks at most 50 first-parent
commits from the merge base and takes the first commit with a stored
result. When there is none, the bench job benchmarks the merge base
itself, before it checks out any PR code. The report job then pushes
that backfill result for reuse.

`report.py` never compares results from different machines. Rows are
marked 🔴/🟢 when |Δ| > 2% and the mean difference is more than the sum
of both standard deviations.

Add the `benchmark-every-commit` label to benchmark every pushed commit
instead of only the newest one. The label takes effect on the next push.

PRs against other base branches than master have no benchmark bot until
the workflows are backported to those branches.

## Runner

Benchmark jobs run on a dedicated self-hosted runner with the labels
`[self-hosted, benchmark]`, inside the container
`ghcr.io/clash-lang/nixos-bittide-hardware:<tag>`. Set up the machine
as follows:

- Register a GitHub Actions runner with the extra label `benchmark`.
  Install docker: the jobs run in a container.
- Keep the machine quiet: no other scheduled work. Set the CPU governor
  to `performance` and turn turbo boost off for stable numbers.
- The cabal store persists on the runner in `/var/cache/clash-bench`
  (mounted into the container as `/bench-cache`). The store is
  disposable. PR jobs run PR code, so wipe this directory when you do
  not trust its content. Numbers are not affected by a wipe, only build
  time.
- Every result records the hostname and CPU model. `report.py` discards
  baselines from a different machine, so replacing the runner machine
  only costs old baselines.

Repository configuration:

- Repo variable `BENCH_RUNS_ON` overrides the `runs-on` labels as a
  JSON array, for example `["ubuntu-latest"]` on a staging fork. Leave
  it unset in production.
- Repo variable `BENCH_QUICK=1` trims the suite to `examples/FIR.hs`
  and skips the wireDemo leg. Use it for fast staging iteration.
- Labels `performance` and `benchmark-every-commit` must exist.
- The orphan branch `benchmark-results` must exist and the Actions
  token must be permitted to push to it.

## bittide-hardware pin maintenance

The wireDemo leg builds pinned revisions with a patch series, because
bittide-hardware does not always build against the newest clash master.
The pins are `bittide-rev`, `clash-cores-rev` and `clash-vexriscv-rev`;
the patches are in `patches/`.

To bump the pins:

1. Update the three `*-rev` files to the new revisions.
2. Recreate the patches from a scratch branch on bittide-hardware:
   apply the same `cabal.project` rewrite (sibling `packages:` paths
   for clash-compiler, clash-cores and clash-vexriscv) plus compile
   fixes, then run `git format-patch --zero-commit --no-signature`.
3. Verify locally: run `.ci/bench/run_bittide.sh` from a clash-compiler
   checkout (directory name `clash-compiler`) with clash master.
4. Land the changes as a normal PR.

`report.py` does not compare wireDemo numbers across different
`bittide_rev` values, so a bump only costs the wireDemo baselines.
