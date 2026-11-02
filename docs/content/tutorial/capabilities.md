# 11. Programming against capabilities

In [chapter 9](effects.md), every computation named one concrete family.
`asks[PricingReader](quote)` is a `Reader[TutorialPricing]` computation, and
`put[State[Int]](15)` is a `State[Int]` computation. To use that `put` inside
`ResultT[State[Int], String]`, the transformer example wrapped it in
`lift[Keep]`. A helper written this way is tied to its family: each caller
with another stack wraps its result in one `lift` per layer above that family,
and adding a layer to the stack changes those call sites.

A capability names an effect operation and the layer it acts on, without
naming the rest of the stack. A helper takes the capability as a type
parameter, and the caller passes a selection for its own stack. In chapter 9's
transformer example, the selected form `put[LiftStateful[Keep, State[Int]]](15)`
has exactly the type that `lift[Keep](put[State[Int]](15))` produced.

| Capability | Operations | Selects | Implemented by | Lift through one layer |
|---|---|---|---|---|
| `Ask` | `ask` | `Environment` | `ReaderT[M, R]`, including `Reader[R]` | `LiftAsk` |
| `Local`, extends `Ask` | `ask`, `local` | `Environment` | `ReaderT[M, R]` | `LiftLocal` |
| `Stateful` | `get`, `modify`, `put` | `StateType` | `StateT[M, S]` | `LiftStateful` |
| `Tell` | `tell` | `Log`, a monoid | `WriterT[M, W]` | `LiftTell` |
| `Listen`, extends `Tell` | `tell`, `listen` | `Log` | `WriterT[M, W]` | `LiftListen` |
| `Censor`, extends `Listen` | `tell`, `listen`, `censor` | `Log` | `WriterT[M, W]` | `LiftCensor` |

Each capability also names its `Family`: the family whose computations its
operations return. A capability is a compile-time dictionary, a trait that
types such as `StateT` and `LiftStateful` implement. It holds no runtime value
and adds no wrapper carrier:
`ask[C]()` returns an ordinary computation of `C.Family`, which you combine and
run as in chapter 9. The names follow [Cats MTL](https://typelevel.org/cats-mtl/),
but selection here is always explicit; the library never searches the stack for
a matching layer.

## Write each step once and choose its layer

A checkout needs the pricing configuration from chapter 9's Reader example and
the ticket counter from its State example. This program writes the two steps
once, then runs the same checkout in a stack with State over Reader and in one
with Reader over State.

<!-- example: docs/examples/capabilities_checkout.mojo -->

`read_pricing[C: Ask]` returns `C.Asked`, the selected family's carrier of the
environment, and raises `C.AskError`, the exact native error of constructing
that read. Its `where` clause forwards `C.AskAvailable`, which holds when the
selected environment can be copied, and requires that environment to be
`Pricing`. `take_ticket[C: Stateful]` has the same shape for `modify`:
`ModifyCompatible[NextTicket]` admits the update, and `C.StateType == Int`
fixes the state it changes. `NextTicket` is a library `Unary` struct, so the
result type can name the callback directly as `C.Modified[NextTicket]`.

Neither helper mentions Reader or State. The caller supplies the selections:

| Stack | `take_ticket` selection | `read_pricing` selection | Runs |
|---|---|---|---|
| `Outer = StateT[Reader[Pricing], Int]` | `Outer` | `LiftAsk[Outer, R]` | `run[Outer]` from ticket 10, then `run[R]` with the pricing |
| `Inner = ReaderT[State[Int], Pricing]` | `LiftStateful[Inner, S]` | `Inner` | `run[Inner]` with the pricing, then `run[S]` from ticket 10 |

A transformer implements the capabilities of the layer it adds, so `Outer`
selects its own state and `Inner` its own environment. `LiftAsk[Outer, R]`
selects the Reader that is `Outer`'s immediate base. Its family is `Outer`, so
the lifted read combines with the ticket update in `pipeline[Outer]`.
`product_r` sequences the update before the read and keeps the read's
`Pricing`; `map(total)` turns it into `12 * 3 + 5 = 41`, and `.get()` returns
the recipe without running it.

Building `counted` runs neither step. `run[Outer](counted^, 10)` consumes the
computation and the initial ticket and returns a Reader computation.
`run[R](reader^, pricing)` borrows the pricing and returns `(41, 11)`: the
total and the next ticket. `ask` copies `Pricing` when the selected Reader
runs, which is why `Pricing` is `Copyable`. The second stack exchanges the
selections and the order of the two runs. `run[Inner]` borrows the pricing and
returns a State computation, which `run[S]` runs from 10, again producing
`(41, 11)`.

Capabilities do not change what a stack returns. These two stacks cannot
fail, so both orders give the same pair; with a stored failure, the
[stack-order rules](effects.md#combine-effects-with-monad-transformers) from
chapter 9 decide whether the final state survives.

## Read and scope configuration through a selected Reader

`Local` adds scoping to `Ask`: `local[C](computation, change)` runs a
computation under the environment that `change` builds from the selected one.
This program runs
one generic read directly, under a State layer with a scope, and against each
of two Readers with the same environment type.

<!-- example: docs/examples/environment_capabilities.mojo -->

`read_config[C: Ask]` forwards `ask[C]()` with its admission predicate. With
`Reader[Int]` as the selection, it reads the environment 5.

The second run places a State layer above the Reader. `LiftLocal[S, R]`
selects the Reader below the State and provides both `Ask` and `Local`, so
one alias serves `read_config[C]()` and `local[C]`. `local` consumes the read
and the `increase` callback. When the Reader runs, `increase` borrows the
current environment 5 and returns 8, which the scoped read observes. The
changed environment exists only during that run. The State passes through
untouched, so the result is `(8, 42)`, and the caller's `environment` is
still 5 afterwards.

`Two = ReaderT[Reader[Int], Int]` has two `Int` environments: 100 for its own
layer and 5 for the Reader below it. `read_config[Two]()` reads 100.
`read_config[Inner]()`, with `Inner = LiftLocal[Two, R]`, reads 5. Selection
is by position, so equal environment types never make it ambiguous.

`ask` copies the environment, so it requires a copyable one. `local` does not:
it borrows the current environment and owns the changed one while the selected
Reader runs, so you can scope a move-only environment. A native callback such
as `increase` borrows its argument as usual. As in chapter 9, `local` rejects
a computation whose result or native error would keep the temporary
environment. A generic scoping helper forwards `C.LocalCompatible[V]` for its
computation type `V` and requires its callback's `Payload` and `Result` to equal
`C.Environment`; see
[environment capabilities](../reference/effects.md#program-against-environment-capabilities).

Chapter 9's `asks` and `inspect` belong to a separate capability, `Project`,
which borrows the environment or state instead of copying it. Lift it with
`LiftProject`; see
[projections](../reference/effects.md#project-without-copying-an-environment-or-state).

## Select a state once and reuse an update

Write a State helper against `Stateful`, name each stack's selection once as a
`comptime` alias, and pass that alias to every call. This program reuses one
generic update through a State, a ReaderT, a ResultT over that ReaderT, and a
stack with two `Int` states.

<!-- example: docs/examples/stateful_capabilities.mojo -->

`add_count[C: Stateful](amount)` adds `amount` to whichever `Int` state `C`
selects. `AddCount` consumes the old state and returns the new one. `modify`
stores that callback and calls it only when the selected State runs, so
building any of these computations calls nothing.

- `run_state[S]` runs `add_count[S](3)` from 10 and keeps only the final state:
  13.
- `RC = LiftStateful[R, S]` selects the State below a
  `ReaderT[State[Int], String]`. Running the Reader with `"config"` returns a
  State computation; running that from 10 gives the same 13.
- `C = LiftStateful[T, RC]` nests one selection inside another, because `T`
  is a ResultT above that ReaderT. `put[C](25)` replaces the selected state, so
  the run returns a successful Result with the state 25.
- `Two = StateT[State[Int], Int]` holds two `Int` states: 100 for its own
  layer and 10 for the State below. `add_count[Inner](3)` changes only the
  inner state, to 13; `add_count[Two](3)` changes only the outer one, to 103.
  `get[Inner]()` returns a copy of the inner state, 10.

The two-State result has the shape `((payload, outer_state), inner_state)`:
the outer run's pair is the payload of the inner State. That is why the example
reads the outer state as `[0][1]` and the inner state as `[1]`.

`get` copies the selected state and requires `GetAvailable`. `modify` consumes
the old state and replaces it with the callback's result; its payload is
`None`. `put` consumes its replacement, and the previous state is destroyed
when the update executes. `modify` and `put` accept move-only state and
captures; a native function or closure passed to `modify` takes its state as
`var`. Capabilities add no rollback: a stored failure keeps or loses the state
according to the stack order, and a raised native error stays a raised error.

## Record, observe and rewrite a selected log

`Tell`, `Listen` and `Censor` select one Writer log by its position. This
program applies the same generic write and observation directly to a Writer,
through two layers above it, and in a stack where the computation fails.

<!-- example: docs/examples/writer_capabilities.mojo -->

`emit[C: Tell]` writes one entry and forwards `C.TellAvailable`.
`hear[C: Listen, V]` pairs a computation's payload with a copy of its log and
forwards `C.ListenCompatible[V]`. The example calls `censor` directly with
`tag`, which consumes the log through its `var` argument and returns the
replacement.

In `Writer[StringMonoid]`, `emit` writes `saved`, `censor` rewrites it as
`[saved]`, and `hear` observes the rewritten log because it listens to the
censored computation. `run_writer[W]` returns `(log, payload)`, so the output
and the observed copy are both `[saved]`.

The second stack places a ReaderT and then a StateT above the Writer.
`LiftCensor[R, W]` selects the Writer below the Reader, and the outer
`LiftCensor[S, ...]` lifts that selection through the State, so one alias
reaches two layers down. The same calls produce the log `[nested]`. The State
layer keeps its own shape: the observation sits beside the payload and the
state stays separate, so the payload is `((None, "[nested]"), 42)`.

`ResultT[Writer[StringMonoid], String]` places the Result inside the Writer.
`flat_map[T]` sequences the write with `reject`, which returns a stored `Err`;
this is ordinary chapter 8 algebra in the selection's family `T`.
The text `attempted` was written before the failure and stays in the Writer,
so `censor` still rewrites it as `[attempted]`. `hear` keeps the error rather
than turning it into success, because there is no successful payload to pair
the observation with. In the opposite order,
`WriterT[ResultFamily[String], StringMonoid]`, a stored failure carries no log,
so neither the observation copy nor the censor callback runs.

`tell` consumes its log. `listen` copies the selected log once, when the
selected Writer's base mapping runs, so it requires a copyable log. `censor`
consumes the computation and the callback, and the callback consumes the old
log, so `tell` and `censor` also work with move-only logs. Observation and
rewriting apply only to the computation you pass; writes sequenced around it
stay outside that scope. To append to an existing computation's selected log
and keep its payload, use `tell[C](log, computation)` with a `Censor`
selection.

## Select layers by position

All three examples follow the same selection rules:

- A transformer implements the capabilities of its own layer: `ReaderT` and
  `Reader` for `Ask` and `Local`, `StateT` and `State` for `Stateful`,
  `WriterT` and `Writer` for `Tell`, `Listen` and `Censor`.
- `LiftAsk[Layer, Capability]` and its siblings select `Capability` in
  `Layer`'s immediate base: `Capability.Family` must be the family `Layer` was
  built on. ReaderT, StateT, WriterT, OptionalT and ResultT support lifting.
  `OptionalFamily` and `ResultFamily[E]`, the Identity specializations of
  OptionalT and ResultT, have no layer below them to select.
- Nest selections to go deeper, one `Lift` per layer crossed, as in
  `LiftStateful[T, LiftStateful[R, S]]`.
- There is no search by type and no preference among layers, so equal
  environment, state or log types stay distinct.
- `LiftLocal` also provides `Ask`, and `LiftCensor` provides `Tell` and
  `Listen`, so one alias can serve every operation on its layer.
- Operations through a selection only construct computations. Lifting
  preserves the layer's logs, unselected states, absence, stored errors and
  native error types. You still run the stack yourself, outermost layer first.

The compiler rejects a selection whose capability is not the layer's immediate
base: `get[LiftStateful[StateT[State[String], Int], State[Int]]]()` fails
because the selection's `GetAvailable` constraint is false. It also rejects a
generic helper that calls an operation without forwarding its admission
predicate, such as `get[C]()` without `where C.GetAvailable`; the
[effects reference](../reference/effects.md#program-against-a-selected-state)
lists each capability's predicates, and the
[architecture chapter](../architecture/algebra.md#environment-capabilities)
explains the checks.

Next, [Programs with IO](io.md) describes native side effects as recipes and
runs them at a host boundary.
