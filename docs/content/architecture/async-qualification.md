# Async overnight qualification

Pass 6 qualifies sustained behavior of the pure-Mojo async preview. Passes 1–5
established its public contracts and source/package compatibility. This pass
adds a repeatable Linux qualification protocol; launching a run or passing its
short calibration does not complete overnight qualification.

**Status: Pass 6 completed.** The twelve one-hour source/package O0/O3 stress
cases and both serial O3 performance runs passed on commit `b753ce9`. An
independent replay of the retained evidence audit also passed. This completes
the planned qualification for the opt-in preview; it does not change its release
status or platform scope.

## Workloads and storage contracts

The clients in `experiments/async-state-machines/stress/` use the canonical
runtime and coordination owners. White-box observations are qualification
instrumentation, not a supported application API.

| Client | Persistent state | Required observations |
|---|---|---|
| `metadata` | One scheduler registry, parent task, signal, and manual clock | Reuse of retired task generations and subscriptions; stale epoch rejection; FIFO duplicate wakes; timer replacement and compaction; fixed node and subscription capacity; no remaining tasks or timers |
| `lifecycle` | One public `tail_rec_m[Async[Int]]` root, host, and manual clock | Immediate and parked completion, timeout fallback, suspending masked withdrawal, rejected duplicate/late move-only payloads, exact destruction, and registry capacity plateau after warmup |
| `workers` | Shared bounded queue and semaphore across repeated roots | The existing six-worker pipeline's success, timeout, cleanup-error and cancellation assertions; queue subscription reuse, fixed queue storage, and restored permits |

The lifecycle host deliberately retains four old completion handles. That fixed
ring exercises late notifications without introducing an ever-growing test log.
Both persistent-clock clients begin at `Int.MAX`, so ordinary timers continue
past the signed timestamp boundary. Earlier deterministic tests cover the
separate low-word carry boundary.

Storage bounds depend on maximum simultaneously retained work. The registry
keeps reusable slots, signal metadata keeps reusable subscriber entries, and
timer compaction bounds stale entries relative to live timers. A nursery keeps
accepted children/results up to its **lifetime admission limit**. This pass does
not require a nursery to forget results that its contract still owns.

The clients assert logical bounds during execution and complete registration
retirement after draining. Process RSS adds an allocator-level observation; it
is not an allocation profiler or proof that every possible workload is leak-free.

## Run window and budgets

Use the pinned Mojo environment and an immutable checkout. Preserve symlinks
when making a snapshot, and do not edit that snapshot while it is running.
Other agents can continue working on shared `nightly` in another worktree.

```sh
pixi run python experiments/async-state-machines/stress.py \
  --output .cache/async-stress/overnight-1 \
  --seconds 3600 --minimum-cycles 10000 --jobs 2
```

The complete stress matrix is three clients × source/package × O0/O3: twelve
one-hour cases, at most two at a time. Budget approximately six hours plus
compilation and serial performance measurements. Each client build has one compiler
thread, a 900-second timeout and a 4 GiB process-tree RSS limit. Each soak has a
512 MiB limit and 300 seconds of timeout allowance beyond its requested window.
Window and cycle floor must both be satisfied. A stalled or zero-work process
cannot qualify by merely staying alive.

The runner samples Linux process-tree RSS every five seconds and retains the
trace while the process is alive. It uses the repository's shared command
runner, process-group termination and raw-log audit; GNU `time` supplies peak
resource accounting. No native backend is added to the Mojo runtime.

After excluding the first 10% of a sustained run, compare the first and last
quarters of retained RSS samples. The late median may exceed the early median
by at most the larger of 4 MiB or 20%; the post-warmup peak allowance is the
larger of 8 MiB or 40%. These explicit tolerances accommodate allocator/cache
settling. The clients' logical capacity assertions remain exact. Missing trace
coverage, exceeded budgets, timeouts, crashes, or input changes fail the run.

A bounded calibration uses the same matrix and auditors:

```sh
pixi run python experiments/async-state-machines/stress.py \
  --output .cache/async-stress/calibration-1 \
  --seconds 120 --minimum-cycles 64 --jobs 2
```

Runs shorter than 120 seconds do not qualify an RSS plateau. Runs shorter than
one hour per case never set `overnight_qualified`, even when every check passes.

## Separate performance measurements

After every stress worker has joined, run the performance client serially through
source and package imports at O3. Each configuration warms up, then retains nine
raw samples and reports minimum, median, nearest-rank p95 and maximum. With nine
samples, p95 equals the maximum; it is a descriptive statistic, not a confidence
bound.

The sequence experiment compares a typed async loop with a native loop doing
the same observable arithmetic at 1,024, 8,192 and 65,536 iterations. Alternating
measurement order and independent checksum verification keep the comparison
honest. It measures the cost of representing every iteration as an async step;
it does not imply that synchronous arithmetic should be written that way.

The parked-work experiment performs 10,000 idle driver calls with 1, 64 and 512
sleeping children, verifies zero child polls/timer events, then times complete
cancellation and draining. Nursery construction is outside those timings.

These are local Linux diagnostics on the recorded compiler, CPU and host. They
do not replace the repository's historical macOS benchmark profile, define a
throughput SLO, or compare Mojo with Cats Effect/JVM or GPU execution. Shared
host load can affect wall times even though this runner's own workers are joined.

## Overnight results

The run started October 29, 2026 at 9:07 p.m. and finished October 30 at
3:37 a.m. America/New_York: 6 hours 29 minutes including compilation. All 14
compiled clients passed their smoke checks before the twelve one-hour stress
cases ran. There were no crashes, timeouts, exceeded memory budgets, changed
inputs, failed assertions, or audit failures.

The host was Linux x86-64 on an AMD EPYC 9V74, using Mojo 1.2.0 (`2016d0cd`).
The [retained results summary](async-qualification-results.json) contains each
route's counters, memory observations, performance distributions, source commit,
and the original report's SHA-256.

| Workload, summed across four routes | Completed cycles | Post-warmup RSS range | Largest early-to-late median RSS increase |
|---|---:|---:|---:|
| Metadata reuse | 425,968,746 | 8.91–9.55 MiB | 0 bytes |
| Persistent callback loop | 111,279,970 | 9.56–10.72 MiB | 8 KiB |
| Structured workers | 12,983,262 | 10.32–12.32 MiB | 8 KiB |

Every stress process ended with zero live task/timer registrations. Across the
callback runs, all 333,839,927 created payloads were destroyed and all 111,279,970
withdrawals completed. Registry capacities, subscription reuse, timer tombstone
bounds, queue capacity and permit restoration satisfied their assertions
throughout the runs. RSS remained well below the 512 MiB per-process budget.
These observations support bounded retained storage for the tested workloads;
they do not prove absence of leaks in every possible client.

After all stress workers joined, each import route supplied nine warmed samples
per performance configuration. All 108 samples passed independent checksum and
zero-idle-work checks. Median observations were:

| Measurement | Source import | Package import |
|---|---:|---:|
| Async sequence, 1,024 iterations | 5.08 ms | 8.97 ms |
| Async sequence, 8,192 iterations | 41.10 ms | 58.62 ms |
| Async sequence, 65,536 iterations | 434.32 ms | 424.82 ms |
| Idle driver call, 1 sleeping child | 192 ns | 187 ns |
| Idle driver call, 64 sleeping children | 222 ns | 183 ns |
| Idle driver call, 512 sleeping children | 246 ns | 179 ns |
| Cancel and drain 512 sleeping children | 2.09 ms | 1.23 ms |

Idle calls performed no child polls or timer events at any tested population.
Cancellation cost increased with the children that had to be drained. The typed
loop cost roughly 5–9 microseconds per iteration, versus roughly 1.4 nanoseconds
for the native arithmetic loop: very fine-grained async sequencing has substantial
overhead. These local measurements establish an initial diagnostic baseline,
not a throughput guarantee. Source/package timing differences and outliers are
not enough to diagnose a regression on a shared host. Future performance work
should profile sequencing costs while preserving the qualified ownership and
cancellation contracts.

The full immutable bundle is retained at
`/workspace/async-pass6-b753ce9/.cache/async-stress/overnight-1/` in the execution
workspace. Its final report declares `passed: true` and
`overnight_qualified: true`; the separate `--audit` invocation returned
`PASS []`. The results summary is committed so other agents can inspect the
findings without relying on that workspace path.

## Calibration and evidence retention

The initial source-import O0 calibration on October 29, 2026 (America/New_York) ran each stress client
for 120 seconds on the pinned Linux toolchain:

| Client | Completed cycles | Early / late median process-tree RSS |
|---|---:|---:|
| Metadata reuse | 196,088 | 9,920,512 / 9,920,512 bytes |
| Persistent callback loop | 145,000 | 10,924,032 / 10,928,128 bytes |
| Structured workers | 19,641 | 12,791,808 / 12,791,808 bytes |

All clients finished with zero live task/timer registrations. The callback
client destroyed all 435,004 created payloads and completed 145,000 withdrawals.
The raw calibration records are retained under
`.cache/async-stress/calibration-probes/` in the development worktree. The O3
performance client's 54 observations also passed checksum and idle-work checks;
those probe timings overlapped compilation and are not the serial baseline.
All 62 tooling tests and the strict rendered-documentation check passed.

These preliminary results cover one import/optimization route; the completed
overnight matrix and separate serial measurements above provide the Pass 6
qualification evidence.

Each fresh output directory retains source and package inputs, executable hashes,
compilation and execution logs, per-case records, RSS traces and the artifact
manifest. `status.json` identifies the active phase; per-case files survive an
interrupted launcher. A final `report.json` records independently rechecked
outcomes. A missing final report is an incomplete run.

```sh
pixi run python experiments/async-state-machines/stress.py \
  --audit .cache/async-stress/overnight-1
```

Audit from the same immutable checkout. It reconstructs the required matrix,
checks raw logs and binaries, independently validates work counters and
performance checksums, and rejects changed inputs or retained artifacts.
Review the finished report before marking Pass 6 complete. Any failure needs a
retained reproducer and a targeted correction before a fresh qualifying run.
