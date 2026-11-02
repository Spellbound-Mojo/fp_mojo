# Migrate to the advanced runtime

The async runtime changed in four ways that need code or review changes. Earlier
previews built programs from typed recipes; every operation now returns one
`IO[T, E]`. Fibers ran on the calling thread; they now run on a work-stealing
pool by default. `par_*` now has two meanings, chosen by the callback's result
type. And `Spawn` gained a member, `background`. The [async runtime
guide](async-runtime.md) describes each feature; this page lists what to change.

## From typed recipes to `IO`

Earlier previews exposed one concrete recipe type per operation. Every
operation now returns `IO`, and a value runs once:

| Before | Now |
|---|---|
| `Pure[T, E]`, `pure[E](value)` | `IO[T, E]`, `IO[T, E].pure(value)` |
| `delay[E](f)`, `eval_io(program)` | `IO[T, E].delay(f)`, `IO[T, E].eval_io(program)` |
| `raise_error[E, T](e)`, `handle_error_with(p, h)`, `attempt(p)` | `IO[T, E].raise_error(e)`, `p.handle_error_with(h)`, `p.attempt()` |
| `both(l, r)`, `race(l, r)`, `race_first(l, r)` | `l.both(r)`, `l.race(r)`, `l.race_first(r)` |
| `timeout_to(p, d, f)`, `timeout_after(p, d, f)`, `sleep[E](d)` | `p.timeout_to(d, f)`, `p.timeout_after(d, f)`, `IO[NoneType, E].sleep(d)` |
| `guarantee(p, c)`, `on_cancel(p, c)`, `guarantee_case(p, f)` | `p.guarantee(c)`, `p.on_cancel(c)`, `p.guarantee_case(f)` |
| `uncancelable(p)`, `uncancelable_with[E](f)` | `IO[T, E].uncancelable(f)`; `f` receives a `Poll[E]` it may ignore |
| `callback(register, withdrawal)` | `IO[T, E].async(register, withdrawal)` |
| `resource(acquire, release)`, `use(body)` | `Resource[T, E].make(acquire, release)`, `use(body)` |
| `resource_case(acquire, cleanup)`, `use(scoped_body)` | `Resource[T, E].make_case(acquire, cleanup)`, `use_scoped(scoped_body)` |
| `Deferred`, `Queue`, `Semaphore` operations | the same names, returning `IO`; `Ref` joins them |
| A custom `Machine` with `Family = Async[E]` | A `Machine`, lifted with `IO[T, E].lift(machine)` |
| `Nursery`, `Spawner`, `scope`, `ScopedBoth` | Removed; start fibers with `io.start()` and join them |

`Nursery`, `Spawner`, `scope` and `ScopedBoth` have no direct replacement,
because fibers now have owners:

- **A nursery that ran children to completion** becomes `start` and `join`,
  or `both` and `par_traverse`, which start, join and drain their children.
  An owner drains the children it never joined before it completes, so no
  scope object is needed.
- **A spawner shared with code that outlives one program** becomes a
  `Supervisor[E].scoped(body)`. Its `supervise(io)` starts fibers owned by the
  supervisor, not by the fiber that calls it, and release cancels or awaits
  the ones still running.
- **`ScopedBoth`** becomes `l.both(r)`: the first side to fail stops the
  other, and both finish, cleanup included, before the result.

Callbacks follow one rule everywhere:
plain functions and library callables that own their state are accepted, and
closures and borrowed callback views are rejected at compile time.

## From the current thread to the pool

Programs now run on the work-stealing pool by default: `run` and `Runtime`
use `Profile.work_stealing()`, one worker per logical processor. A host with a
single logical processor keeps the current-thread profile, since a one-worker
pool would only add its costs. An explicit `IORuntimeConfig.profile` always
wins, and `Driver` and `TestControl` always use the current thread.

**To keep the earlier behavior**, select the current-thread profile:

```text
var config = IORuntimeConfig()
config.profile = Profile.current_thread()
var outcome = run(program^, config)
```

Before moving a program to the pool, review four things.

**Shared state.** Fibers now run at the same time on different threads, so
the [thread-safety contract](async-runtime.md#share-state-across-threads)
matters:

- an `ArcPointer` to mutable data that two fibers both change is a data race;
  share a `Ref`, or an `ArcPointer` to atomics, instead;
- every value the runtime holds for a program must be safe to move to, use
  on and destroy on another thread;
- the compile-time check rejects a payload that reaches a raw `Pointer`
  through a type that does not conform to `ThreadTransferable`. Claim
  `ThreadTransferable` only for a type that owns or synchronizes what it
  points to. `assert_thread_transferable[T]()` checks your own state types
  more strictly, rejecting `ArcPointer` outside such a type too.

**Orderings.** A fiber's steps, `Queue` order and `Deferred` readers keep their
guarantees. A race's tie may now go to either side, and ready fibers and
waiters run in no fixed order. A test that depends on those orders belongs
under `TestControl`, which stays deterministic; see
[profiles compared](async-runtime.md#profiles-compared).

**Costs.** Benchmark measurements on a 4-core host indicate:

- fibers that cede to each other cost about twice as much: a ceding pair
  takes about 36 µs against 18 µs. For code dominated by ceding hand-offs,
  use `Profile.current_thread()`, or hand off through a `Deferred` or `Queue`
  ([ceding pairs](../architecture/async-scheduler.md#ceding-pairs-and-notification-policy));
- each free `run` makes a pool for the call, about 1 µs more: create one
  `Runtime` and run many programs on it;
- `both` and `race` of pure sides cost 15 to 25% more;
- an idle program uses about 0.3 ms more CPU per 2 s;
- CPU-bound fibers run in parallel: about 1.9 times faster on 2 cores, and
  3.5 to 4 times on 4. Fiber pairs and joins cost the same on both profiles.

**Blocking and locks.** A blocking call runs on the thread that made it, and
the worker's queue moves to a replacement thread. A configured
`IORuntimeConfig.blocking_pool` is still honored on both profiles, so a
program that serialized its calls through `BlockingPool(1)` keeps doing so.
A contended `Ref`, `Deferred`, `Queue` or `Semaphore` lock polls on the pool,
so callbacks under it, such as `Ref.modify`'s, must stay short.

<!-- example: docs/examples/async_thread_safety.mojo -->

## Implementors of `Spawn`

`Spawn` gained `background` in this release (1.0.2), after Cats Effect's
`GenSpawn.background`: an associated `Backgrounded[V]` and a static
`background[V](var program: V) -> Backgrounded[V]`. The library's providers,
`Async[E]` and the `Lift*` selections, have it. A capability dictionary
written outside the library that conforms to `Spawn`, directly or through
`Concurrent` or `Temporal`, no longer compiles until it adds both; a
dictionary that forwards to a base can forward them as `LiftSpawn` does.
Code that only uses `Spawn` is unaffected.

## Validation `par_*` beside concurrent `par_*`

`par_traverse`, `par_sequence`, `par_map_n` and `par_product_n` select their
family from the callback's result, as Cats' `Parallel` does:

| Callback returns | Family | What happens |
|---|---|---|
| `Result[T, E]` with a combinable error | `ValidationFamily` | Every element runs in sequence on the calling thread; every error is collected. No fibers. |
| `IO[T, E]` | `AsyncPar[E]` (`Async[E].Par`) | Every element's `IO` runs as a child fiber, in parallel on the pool; the first failure stops the rest; results keep source order |

Existing validation code keeps its meaning: a `Result` callback never starts a
fiber. Code that used `traverse` with an `IO` callback to run elements one after
another keeps that behavior, too. Switch it to `par_traverse` only when elements
wait or work for tens of microseconds or more, since each element costs about
one fiber start, around 5 µs. `par_traverse_n` bounds how many run at once.
`SyncIO[E]` has no `Parallel`, and is rejected at the call.

The [concurrent traversal example](async-runtime.md#run-a-collection-concurrently)
runs both kinds side by side.
