# Choose an API for your task

Start with the value you have and the work you want to perform. Ordinary
functions and closures can be passed directly to the operations below. Introduce
a reusable callable when you need to store or compose a computation.

| Your task | Start with | Finish with |
|---|---|---|
| Transform or recover one success/failure value | Direct `Result` methods: `map`, `flat_map`, `recover`, `fill`, `void` | `get_or`, `value_or`, `to_optional` or `raise_on_err`, according to the desired failure behavior |
| Chain operations on a collection, Optional or Result | `pipeline(value)` | `.get()` for the carrier, or a terminal such as `.fold(...)` or `.get_or(...)` |
| Process a sequence lazily or stop after a prefix | `iterated(source)` | `.to_list()`, a fold, a search, or native iteration |
| Capture an immediate native call's raised error | `Capture[E]` | `.run(callback)` after binding any arguments |
| Build a function to call later | `flow`, `compose` or `partial` | Pass the resulting callable directly to an operation |
| Repeatedly call a native function with owned mutable state | `Capture[E]().stateful(step, state^)` | Pass `mut_ref(owner)` to map or traverse; inspect `state()` or consume `into_state()` afterward |
| Acquire resources and release them after use | `resource[E](acquire, release)` | `.use(callback)` on the consumed scope |
| Describe deferred IO with explicit finalization or cancellation | `pipeline(delay[E](callback))` and `.guarantee(cleanup)` | `.run_io()` or `.run_io(token)` at the execution boundary |

The [pipeline tutorial](../tutorial/pipelines.md), [iteration tutorial](../tutorial/iteration.md)
and [Result tutorial](../tutorial/results.md) develop the first four choices.
The [effects reference](../reference/effects.md) covers resources and IO.

Reader, State, Writer and IO values already identify their family, so
`pipeline(recipe).map(callback)` uses that family automatically. The chain
retains deferred execution. Choose an explicit family for a different policy
or an erased transformer layer; see [effect-family inference](../reference/functions.md#inference-for-effect-recipes).
Finish a Reader chain with `.run(environment)`, a State chain with
`.run(initial_state)`, or unwrap a Writer chain with `.run()`. Writer returns
its base carrier without executing a deferred base. Use `.get()` to extract
an unexecuted recipe. IO pipelines use `.run_io()` at their execution boundary;
the free `run_io(program^)` entry also remains available.
State chains can use `.run_value(initial_state)` or `.run_state(initial_state)`
when only one output is needed; both preserve the base effect without copying
the unused tuple element.
Writer chains use `.run_value()` for the payload or `.run_log()` for the log,
with the same ownership and base-effect preservation.
Reader chains can scope configuration with `.local(callback)`. Writer chains
can observe their log with `.listen()` and transform it with `.censor(callback)`
before `.run()`. These use the current family's capabilities; explicit lifted
capabilities remain the path for selecting an inner transformer layer.

## Work directly with a Result

Use direct methods when the task is about one Result. `map` transforms an Ok,
`flat_map` continues with another Result, and `recover` computes a replacement
success from an Err. `fill(value)` replaces a success with an already computed
value; `void()` discards it while keeping success or failure. `tuple_left(value)`
or `tuple_right(value)` keeps the success and attaches another value beside it.

Choose `pipeline(result^)` when the task needs container capabilities such as
`map_n`, accumulation with `par_map_n`, or traversal. A chain can continue
through Result-specific operations without extracting and wrapping every step.
The [validation example](../reference/combinators.md#accumulate-independent-validation-errors) combines independent checks
with the same Result type used for dependent steps.

## Choose eager or lazy collection processing

For a named List, `pipeline(values^)` selects its elements. Each eager stage
finishes before the next starts. Use `iterated(values^)` for a lazy chain:
callbacks run as the consumer pulls values, and early stopping avoids reading
the rest of the source. An existing iterator continues from its current position.

List literals need their element type, as in `pipeline[Int]([1, 2])`. For an
Array or another supported native sequence, `.elements()` selects element
operations explicitly. `.then(function)` always handles the entire current
value once; `.map(function)` follows the selected family.

Moving a named value uses `^`. Use `.copy()` explicitly when the original must
remain available. Borrowed lazy sources and callbacks must outlive the chain.
Lazy mapping and filtering callbacks cannot raise; Result elements can carry
failures to a terminal. See [ownership and errors](ownership.md) for the complete
receiver and source contracts.

## Select how errors are handled

A stored Result error, a native raised error and IO cancellation are different
outcomes. Select the behavior at the boundary where it matters:

- A Result transformation preserves Err; a recovery operation handles it.
- `.raising[E]()` selects subsequent native callback admission on a Pipeline;
  it does not catch errors or change the stored Result error type. A raising
  plain function selects its own error when none is selected.
- `Capture[E]().run(callback)` catches a zero-argument native call immediately.
  Bind owned arguments with `.args(...)`, or mixed conventions with `.borrow`,
  `.mutable` and `.take`, before `.run(callback)`.
- IO construction defers execution. `run_io` distinguishes cancellation from
  completed success or failure; finalization follows the IO contract.

Prefer a native function or closure for a single callback. `partial` binds a
positional prefix for reuse and has explicit copying semantics. Use `flow` or
`compose` to store a chain of ordinary transformations, and
`kleisli[Family]` to store a chain whose steps return effects. The
[callback guide](ownership.md#choose-a-callback-form) covers shared and mutable
references, consuming callbacks and selected native signatures.

## Move to generic code when the task requires it

Explicit families choose semantics: a custom accumulation policy, a deferred
Reader computation, or an algorithm generic over a capability. Public operation
contracts expose the output family, result, native error and admission rules
for [generic wrappers](../guides/generic-wrappers.md). Ordinary concrete calls
do not need to reconstruct those contracts.

Existing free functions, `pipe` and compatibility adapters remain supported.
Use them when maintaining code written to their documented contracts or when a
direct function fits the surrounding algorithm. The preferred entry points
above provide a consistent starting path; they do not change existing
positional bindings or imply that all native signatures have identical compiler
behavior. The [compatibility guide](../guides/compatibility.md) records those
boundaries separately from the everyday workflows.
