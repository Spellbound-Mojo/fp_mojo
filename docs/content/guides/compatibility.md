# Mojo 1.2 compatibility and migration

Use `Pipeline` and `Capture` for new native callback code. They select semantic
context before matching a callback. Existing free functions, `Piped`, Result
methods and iterator APIs remain available under their documented contracts.
The published FP Mojo 1.0.0 package targets Mojo 1.1; Mojo 1.2 users currently
use the `nightly` source checkout.

## Qualification checkpoint

The baseline below qualifies production source at
[51997ac](https://github.com/Spellbound-Mojo/fp_mojo/commit/51997aca96c3256a90bf6abdd4074a79f517a117)
with Mojo 1.2.0 (2016d0cd), Linux x86-64. Later migration passes have their own
retained reports; this checkpoint does not silently advance when code changes.
All baseline reports have unchanged inputs and zero audit failures.

<!-- compatibility: qualification -->

The checkpoint also passed 38 tooling tests and a strict documentation build.
The [downloadable catalog](../downloads/docs/compatibility.json) records the
source commit, production tree, report digests, representative evidence,
operation contracts and migration assignments. Raw logs and executables are
retained in local `.cache` run folders; the catalog is a summary, not a portable
copy of those artifacts. The commands in
[development](../contributing/development.md#verification-gates) reproduce the gates.

macOS arm64 has a locked environment but has not been qualified on Mojo 1.2 in
this work. Device compilation does not establish GPU execution support. A green
host suite does not prove that every invalid legacy native call diagnoses
normally: the catalog identifies the 22 historical diagnostic controls that
bind callback types explicitly. Crashes and timeouts never count as rejection.

## Package coverage

Every public package is classified below. The reviewed export inventory owns
individual names and signatures; this catalog adds scope, restrictions and
representative checked clients. A package's examples do not imply exhaustive
coverage of all native signatures. Its reference and architecture pages retain
the detailed operation contracts.

<!-- compatibility: packages -->

## Selected Pipeline contracts

`selected` means the operation is exposed through the selected family/native
error boundary. `result_only` means the current method requires a Result
carrier, even when a same-named legacy operation also accepts generic families.
Method-name equality alone does not establish feature parity.

<!-- compatibility: pipeline -->

Native closures retain their borrow origins; stored thin pointers keep their
native calling conventions. Library callbacks retain their declared receiver
modes and errors. `raising[E]()` selects subsequent native callback admission;
it is independent of stored Result errors and does not bound every family or
library-callable error. Construction and deferred execution can raise different
errors at different times. Generic forwarding carries the family's public
admission predicates in the signature, including embedded origins.

`Capture[E]` currently binds zero to two positional operands with read, mutable
or consuming conventions, followed by an optional homogeneous native keyword
pack. Empty packs need a type; larger packs, fixed named parameters and defaults
use an explicit native closure or OnceThunk. Stateful repeated calls use an
owned state value and a plain mutable-state function. These restrictions are
tracked for ergonomic review; they are not claims of arbitrary native-call parity.

## Remaining Pipeline migration

The catalog assigns every legacy Piped method absent from Pipeline to one pass.
The documentation audit rejects missing, duplicate or stale assignments. These
operations already have execution owners; migration adds selected admission and
delegation. Each pass checks ordinary invalid calls without compiler-type hints.

<!-- compatibility: migration -->

After those passes, same-named Result-only methods need capability review for
generic recovery, observation and sequencing. Iterator, transformer, Ior and
custom-family contracts also need evaluation beyond a count of public names.

## Development sequence

1. Maintain this compatibility inventory and reconcile current guidance.
2. Complete the selected API workflow passes above.
3. Stabilize family admission and public generic-extension contracts.
4. Improve argument binding, reusable state and diagnostics against real clients.
5. Measure compilation/runtime costs and qualify a clean release candidate on
   each advertised platform, with a migration guide and explicit version decision.
6. Consolidate compatibility code once replacement coverage is established;
   design Resource scopes and fallible streams as separate ownership contracts.

Each implementation pass includes focused verification, appropriate regression
gates, documentation, a commit and a push to `nightly`. Verification is run
locally; adding CI is outside this agreed sequence. Existing positional bindings
and legacy entry points remain supported during migration. New release versions,
deprecations and supported-platform claims must follow the demonstrated contract.
