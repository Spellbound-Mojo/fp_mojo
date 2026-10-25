# fp.functions

`fp.functions` provides eager pipelines, function composition and partial
application. Use `pipe` to apply a sequence of functions now, `flow` or `compose`
to build a function for later calls, and `partial` to bind leading arguments.
The [pipeline tutorial](../tutorial/pipelines.md) starts with a complete program.

Use `.map(transform)` to preserve a supported native container and map its
payloads immediately. Use `.map[Family](transform)` for an explicit Functor
instance. `.filter(predicate)` and `.filter_not(predicate)` eagerly preserve supported
containers, and
`.fold_left(step, initial)` consumes an iterable immediately and keeps its
result in the chain. `.get()` extracts the stored value. See
[combinators](combinators.md) for supported containers and lazy alternatives.
`Piped` names its payload parameter `Value`: explicit `Piped[T=Int]` and
`Piped[Int].T` become `Piped[Value=Int]` and `Piped[Int].Value`.

## Select family and native errors before callbacks

`pipeline(values)` starts a `Pipeline` for List, Optional or Result. Other
values use Identity: `map` applies its callback to the whole bare value once.
`pipeline[Family](value)` selects another Functor explicitly, including a
deferred family. Call `raising[E]()` once to select native callback errors.
Existing explicit payload bindings, such as `pipeline[T=Int](values)`, remain
available. Generic wrappers over an unknown value type select a family
explicitly; use `pipeline[IdentityFamily](value)` for a whole-value stage.
`map`, `filter`, `flat_map` and `filter_map` use the selected family's
capabilities. Result combinators use their existing branch and ownership rules.
The result of `map_err` or `map_both` selects the new Result error family.

<!-- example: docs/examples/selected_pipeline.mojo -->

`raising[E]()` selects native callback admission. It does not change stored
errors, catch exceptions, or restrict the errors declared by library callables.
Pure and Never callbacks retain Never. Custom families retain their own
execution errors and deferred callback lifetimes. `get()` only extracts the
carrier.

`then(stage)` consumes the whole current value once, including a Result's Err.
It selects List, Optional or Result for those output types and Identity for
other outputs. Use `then[Family](stage)` when returning a custom carrier, or
`then[IdentityFamily](stage)` to treat a native container as one payload.
The selected native error remains in effect across these transitions.

`fold_left(step, initial)`, `fold_until(step, initial)` and
`reduce_optional(step)` use the existing consuming iterator drivers. Folds
preserve source order and stop immediately on a raised error; `fold_until`
also stops on Break without another pull. Empty `fold_left` returns its initial
value; empty `reduce_optional` returns None. Native steps are borrowed;
library steps use the standalone folds' shared `Binary` contract. The resulting
value selects its family by the same rule as `then`.

`traverse[TargetFamily](transform)` and `sequence[TargetFamily]()` continue in
the target effect family. `map2(other, combine)`, `product(other)`,
`map_n((other, ...), combine)` and `product_n((other, ...))` retain the current
Applicative family. The n-ary forms accept one to eight total operands; native
functions take separate payload arguments, while library Unary callables take
one tuple. Operands are already evaluated and are consumed once. Result keeps
its first stored error, Optional skips absent inputs, and List produces
Cartesian combinations. Selecting `ValidationFamily[Semigroup]` explicitly
accumulates stored errors through the same operations.

<!-- example: docs/examples/selected_workflow.mojo -->

This checkout selects its native error once, traverses into Result, folds the
collected amounts, and combines shipping and tax. Invalid amounts remain stored
errors; transport failures remain native raised errors. Existing `Piped` remains
available, including operations not yet exposed through `Pipeline`.

A generic bind wrapper retains a family parameter (`I: Monad`, optionally
`I: Monad = ResultFamily[E]`) and forwards `I.BindCompatible[V, F]`,
`I.Element[V]`, `I.Bound[V, F]` and `I.BindError[V, F]`. This lets Mojo check
the full carrier and its origins when the family is selected. Naming a concrete
`ResultFamily[E]` in a generic constraint can inspect the callback too early;
an output equality alone does not supply the projection proof. This applies to
generic algebra bind wrappers too. Ordinary calls need no extra arguments;
a default family also preserves a wrapper's existing call syntax.

<!-- api: functions -->

## Chain ten stages with pipeline

<!-- example: docs/examples/chained_pipeline.mojo -->

`total("1999", 3, 10, 499)` runs ten `then` stages: plain functions, two
closures that capture `percent` and `shipping`, and two partials. The price
`1999` cents times 3 is `5997`; the 10% discount gives `5398`, the `-500`
coupon `4898`, shipping `5397`, and 8% tax `5828`, which rounds to the nickel
as `5830` and prints as `total: $58.30`. With `"19.99"`, `parse_cents` raises
`PriceError`, no later stage runs, and the program prints
`invalid price: 19.99`.
The entry point selects `PriceError` once; subsequent pure stages retain Never.

## Bind leading arguments with partial

<!-- example: docs/examples/partial.mojo -->

`partial(twice, value)` copies `4` when it is built and passes a fresh copy on
each call, so `doubled()` returns `8` twice. `partial(scale, 3)` binds the first
argument, and `triple(5)` returns `15`. `partial` binds only a positional
prefix, so the keyword `base=2` is bound by the closure `basetwo`, which
returns `18` for `"10010"`.

## Compose effectful functions

`kleisli[Family](parse).then(validate).map(render)` stores one computation for
later calls. `then` passes each successful payload into the next effectful
function. `map` transforms the payload inside that effect. The family supplies
sequencing: Result skips later stages after an `Err`, Optional after absence,
and List expands each branch in order.

<!-- example: docs/examples/kleisli.mojo -->

Both `piped(values^).map(chain)` and `iterated(values^).map(chain)` accept the
chain directly and borrow it without copying its callbacks. The eager form
maps immediately; the iterator calls it as elements are pulled. These forms
keep each returned Result as an element. Use
`.traverse[ResultFamily[String]](chain)` to gather successes into one Result
and stop at the first stored error. Direct `Result.map(chain)` and
`Result.flat_map(chain)` work as well; `flat_map` sequences the returned Result.

`chain.call(input)` borrows shared callbacks, `chain.call_mut(input)` reuses
mutable callback state, and `chain^.call_once(input)` consumes the chain.
Deferred families such as Reader and State retain the borrowed callbacks until
the resulting computation finishes; consuming invocation transfers ownership
instead. Keep a borrowed chain alive and unmoved while its iterator or deferred
results still need it. Automatic callback adaptation uses shared calls; lazy
mapping also requires that the call cannot raise. A stored Result error remains
ordinary data and is allowed in a lazy iterator.

`.compose(before)` prepends an effectful function of the same family;
`.contramap(prepare)` prepends an ordinary input transformation. All four
composition methods consume the previous chain and the new callback. Owned
captures move into it; captured references keep their native origins. A chain
can be copied explicitly when all its callbacks are copyable. Native raised
errors remain separate from Result errors and must agree across reached stages.

For generic native forwarding, keep `A`, `R` and `E` as the complete native
signature, `F: def(var A) raises E -> R`. Inside that generic wrapper, construct
`NativeUnary[A, R, E, F, True](f^)` from `fp.callables` before passing it to
`kleisli[Family]`. This fixes the signature evidence across module and package
boundaries on Mojo 1.1. A Result family also needs signature evidence that `R`
is its exact carrier, including stored-error origins:
`R == ResultFamily[Failure].Pure[ResultFamily[Failure].Element[R]]`.
