# Async overnight qualification

This repeatable Linux qualification protocol checks sustained behavior of the
pure-Mojo async runtime, complementing its deterministic public-contract and
source/package tests. Launching a run or passing its short calibration does not
complete overnight qualification.

**Status: overnight qualification passed.** The twelve one-hour source/package O0/O3 stress
cases and both serial O3 performance runs passed on commit `b753ce9`. An
independent replay of the retained evidence audit also passed. These results
qualify the tested runtime on Linux x86-64; macOS arm64 is covered by the
focused source/package suites and a one-hour soak.

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
timer compaction bounds stale entries relative to live timers. Fiber hosts
reuse completed slots, so storage follows the most simultaneously live fibers.
The recorded overnight run predates fibers: its parked-work and worker clients
then used the private nursery, which kept accepted children and results up to a
lifetime admission limit. The maintained harness runs them as fibers.

The clients assert logical bounds during execution and complete registration
retirement after draining. Process RSS adds an allocator-level observation; it
is not an allocation profiler or proof that every possible workload is leak-free.

## Run window and budgets

Use the pinned Mojo environment and an immutable checkout. Preserve symlinks
when making a snapshot, and do not edit that snapshot while it is running.
Other work can continue in another worktree.

```sh
pixi run python experiments/async-state-machines/stress.py \
  --output .cache/async-stress/overnight-1 \
  --seconds 3600 --minimum-cycles 10000 --jobs 2
```

The complete stress matrix is three clients × both profiles × source/package
× O0/O3: twenty-four one-hour cases, at most two at a time. Each build selects
its profile with `-D FP_ASYNC_PROFILE` (`current_thread` or `work_stealing`),
since the work-stealing pool is the default and the current-thread profile
stays supported. Budget approximately twelve hours plus compilation and
serial performance measurements; `--seconds 1800` keeps the earlier six-hour
window. Each client build has one compiler
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
source and package imports at O3, on each profile. Each configuration warms up, then retains nine
raw samples and reports minimum, median, nearest-rank p95 and maximum. With nine
samples, p95 equals the maximum; it is a descriptive statistic, not a confidence
bound.

The sequence experiment compares a typed async loop with a native loop doing
the same observable arithmetic at 1,024, 8,192 and 65,536 iterations. Alternating
measurement order and independent checksum verification keep the comparison
honest. It measures the cost of representing every iteration as an async step;
it does not imply that synchronous arithmetic should be written that way.

The parked-work experiment performs 10,000 idle driver calls with 1, 64 and 512
sleeping fibers, verifies zero polls/timer events, then times complete
cancellation and draining. Starting the fibers is outside those timings.

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

## Comparison with the foundation

The advanced runtime was benchmarked against earlier versions of the library to
measure performance and allocation scaling under Mojo 1.2.0:

- **The foundation**: the single-threaded cooperative host with typed recipes;
- **Unified `IO`**: replacing typed recipes with unified `IO[T, E]`;
- **The multi-threaded runtime**: configured with both single-threaded and
  work-stealing profiles.

The foundation comparison reuses the maintained clients under
`experiments/async-state-machines/stress/`, which exist at both commits with
the same workloads. The initial `IO` baseline comparison uses
`experiments/async-state-machines/probes/foundation_compare.mojo`, restricted to the API that existed at commit `e4cad044`,
because the stress clients were migrated to `IO` later. The
1-minute load average was 1.0 to 3.1, from these runs and the builds just
before them; no other work ran.

### Performance

| Measurement | Foundation | Initial baseline | Current thread | Pool |
|---|---|---|---|---|
| Async loop iteration, 1,024 to 65,536 iterations (`tail_rec_m`, stress `performance`) | 5.77–5.82 µs | — | 49–51 ns | 50–64 ns |
| `flat_map` recursion, per step, 1,000,000 steps | — | 14.5, 18.0 ns | 14.3, 14.0 ns | 17.9, 17.9 ns |
| Runtime-built `map` chain, build and run, per stage | — | 20.3, 20.1 ns | 20.5, 20.9 ns | 22.3, 22.1 ns |
| Trivial `run(IO.pure(i))` | — | 1.09, 1.40 µs | 2.24, 2.24 µs | 3.89, 3.96 µs |
| Idle `Driver.poll`, 1, 64 and 512 sleeping fibers | 297, 279, 268 ns | — | 284, 285, 288 ns | 289, 293, 287 ns |
| Cancel and drain 1, 64 and 512 sleeping fibers | 26 µs, 207 µs, 1.46 ms | — | 9.5 µs, 173 µs, 1.58 ms | 17 µs, 190 µs, 1.54 ms |

Medians of nine samples. Where a cell has two values, they come from two
rounds of the probe, interleaved across the builds.

- **Sequencing** is about 115 times cheaper than the foundation's typed
  recipes, and the bind itself is unchanged from the initial baseline: the per-step costs
  overlap. This host is bimodal for this loop on every tree (benchmarks measured 17
  or 33 ns per step), so the pool's 18 ns is not a regression.
- **A trivial `run`** costs 0.8 to 1.2 µs more than the initial baseline on the current
  thread, for the fiber table, the poller hook and the wake handshake. The free `run` on the pool makes a pool for the call, and
  costs 1.7 µs more again. A long-running program should create one `Runtime`.
- **Idle driving and cancellation** cost the same as the foundation. `Driver`
  always uses the current-thread profile, so its idle poll does not depend on
  the build's profile.

### Allocations and storage

Allocation counts come from an `LD_PRELOAD` shim that counts
`KGEN_CompilerRT_AlignedAlloc`, the allocator every Mojo heap allocation goes
through (Valgrind does not run these binaries). Peak RSS comes from GNU `time`.

| Measurement | Initial baseline | Current thread | Pool |
|---|---|---|---|
| Allocations per `flat_map` step | 0 | 0 | 0 |
| Allocations per `map` stage of a chain, beyond the frame stack's growth | 0 | 0 | 0 |
| Allocations per trivial `run` | 8 | 18 | 44 |
| Peak RSS, `flat_map` recursion of 100,000 and 4,000,000 steps | 9.7, 9.9 MiB | 10.1, 9.9 MiB | 10.2, 10.1 MiB |

Each soak below ran 60 seconds, the three clients side by side, and passed the
client's own storage assertions; 60 seconds is a calibration, not a
qualification.

| Soak, 60 s | Foundation | Current thread | Pool |
|---|---|---|---|
| `metadata`: cycles; peak RSS | 2,629,104; 10.1 MiB | 1,617,790; 10.1 MiB | 1,598,681; 10.1 MiB |
| `lifecycle`: cycles; peak RSS; node capacity | 878,377; 10.6 MiB; 16 | 3,384,272; 10.4 MiB; 4 | 3,340,673; 10.3 MiB; 4 |
| `workers`: cycles; peak RSS | 104,306; 11.7 MiB | 210,152; 11.1 MiB | Aborted at once |

- **The bind allocates nothing**, as in the initial baseline, and deep programs keep a flat
  footprint on both profiles. A `run` allocates its root: 8 blocks initially,
  18 now, and 44 for the per-call pool.
- **Pooling is not justified by these counts.** The allocations are per root
  and per fiber, not per step: about fifteen owners with different lifetimes,
  at most about 12% of a fiber start. Pooling was evaluated and not adopted
  (see [allocation ownership](async-fibers.md#allocation-ownership)).
- **Retained storage stays bounded.** Every soak ended with no live
  registrations, and with as many payloads destroyed as created.
  `lifecycle`'s task table now peaks at 4 nodes, down from 16. `metadata`
  completes 39% fewer cycles than the foundation, at 37 µs per cycle against
  23 µs, a cost of the fiber and timer bookkeeping that the foundation's
  driver did not have. `lifecycle` and `workers` complete between two and
  four times more.
- **`workers` on the pool** stops at its first cycles: the client requires the
  queue's wait-entry capacity to stay exactly what it was in the first cycle,
  and on the pool the first cycle can leave it smaller. The pool build of
  the stress clients is not qualified; the long-lived storage soak is the
  `storage_soak` client ([long-lived roots](async-fibers.md#long-lived-roots)).

These figures describe this host and these workloads. They are not a
throughput guarantee, and they make no claim about parity with Cats Effect
on the JVM, or with native code.

## Evidence retention

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
Review the finished report before accepting qualification. Any failure needs a
retained reproducer and a targeted correction before a fresh qualifying run.

### Retained summaries

A bundle stays in the checkout that produced it: its executables and raw logs
are too large to commit. What is committed is a summary, one JSON file per
bundle under [`evidence/`](https://github.com/spellbound-mojo/fp_mojo/tree/main/docs/content/architecture/evidence),
written by `scripts/retain_evidence.py` (`fp_tools/evidence.py`). A summary
records:

- the source commit, whose tree reproduces the run's inputs;
- the SHA-256 of the bundle's final `report.json`;
- the digest and count of the input hashes the report recorded, and of the
  experiment's inputs for `qualify.py` and `stress.py`;
- the host, the host load its operator noted, and the defines, such as
  `FP_ASYNC_PROFILE=work_stealing`;
- each check's name, outcome, and executable and output hashes.

Retention re-audits before it writes. The bundle's own runner re-derives every
outcome from the raw logs and binaries: `qualify.py --audit`, `stress.py
--audit`, or `verify_docs_examples.audit_report` for `docs-test`. It also
checks the artifact manifest and requires a clean checkout whose inputs equal
the run's. Nothing is written if any check failed or any evidence changed,
and an existing summary is never overwritten. Committed summaries are left
out of the input comparison, so a gate's bundles can be retained one after
another and committed together.

A long run records into it in three steps, from one immutable checkout:

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/pass14-gate --jobs 2
pixi run python experiments/async-state-machines/qualify.py --audit .cache/pass14-gate
pixi run python scripts/retain_evidence.py --kind qualification \
  --bundle .cache/pass14-gate --label pass14-gate --host-load "1-minute load 2.1 to 3.4"
```

Then commit `docs/content/architecture/evidence/pass14-gate.json`.

The first three summaries were retained from `713b83d`: the async examples
through `docs-test` on each profile, 60 of 60 checks each
([current thread](evidence/pass14-q3-docs-async-current-thread.json),
[pool](evidence/pass14-q3-docs-async-work-stealing.json)), and a targeted
qualification of `public_runtime`, 4 of 4
([summary](evidence/pass14-q3-public-runtime.json)). The tooling
tests check every committed summary's schema and counts. A summary never
replaces a bundle's audit: to re-audit, keep the bundle, or rerun the commit's
gate.
