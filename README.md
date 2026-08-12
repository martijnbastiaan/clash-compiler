# Benchmark results

Machine-written benchmark results for the Clash benchmark bot. Do not edit by
hand; files are appended by the `benchmark-master.yml` and `benchmark-pr.yml`
workflows (see `.ci/bench/` on `master`).

## Layout

    results/<sha[0:2]>/<full-sha>.json

One file per benchmarked clash-compiler commit, `result.json` schema v1:

```json
{
  "schema_version": 1,
  "clash_commit": "<sha>", "parents": ["<sha>"],
  "date": "...", "source": "master" | "pr-backfill",
  "machine": {"hostname": "...", "cpu": "...", "container": "..."},
  "ghc_version": "9.10.x",
  "normalization": {"examples/FIR.hs": {"mean_s": 1.234, "stddev_s": 0.011}},
  "wire_demo": {
    "status": "ok" | "skipped", "skip_reason": null,
    "bittide_rev": "<sha>",
    "runs": [{"normalization_s": 312.4, "netlist_s": 95.1, "total_s": 490.2}]
  }
}
```
