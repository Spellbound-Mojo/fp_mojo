# Design principles

These rules decide what the library contains and how it is built. Every
architecture chapter applies them; a change that breaks one needs an explicit
decision, not a workaround.

## Native Mojo first

1. **Ordinary Mojo only.** The library is used through normal imports,
   functions, closures, structs, traits and parameters. There is no parser,
   transpiler, source rewriting, mandatory code generation or Python runtime.
   Compile-time programming in Mojo itself is allowed.
2. **Use the native capability.** When the language, compiler or standard
   library provides a behavior, use it directly and teach its native spelling.
   `Optional`, `Variant`, `Tuple`, `List`, `Span`, `Pointer`, `SIMD`, native
   closures, typed errors, `reflect`, `Iterator`, `std.iter`, `std.itertools`
   and `std.testing` are used as they are. An Optional transform is not a
   separate Maybe type.
3. **Add the smallest missing piece.** When a native capability covers part of
   a contract, add only the missing adapter or specialization, reuse native
   control flow, ownership and storage, and state the exact gap it fills.
4. **Converge.** When Mojo adds an equivalent capability, adopt it and delete
   the library's version. A library component disappearing because the
   language caught up is a success. A replacement that changes ownership,
   errors, ordering or empty-input behavior is published as a named breaking
   change with a migration, never as a silent cast between representations.
5. **Accept native limits.** The library does not emulate another language's
   features where Mojo cannot express them. For example, `partial` binds a
   positional prefix of a plain function, and keyword binding is a native
   closure (see [functions](functions.md#partial-application)).
6. **No compiler or standard-library changes.** Work that requires modifying
   Mojo is outside the project. A rejected native encoding is an observation
   about one program on one toolchain; look for a different library
   representation or call boundary before concluding a feature is impossible.

## One implementation per concept

Each shared concept has exactly one implementation, at the lowest layer that can
own it. User-facing packages delegate to it; public overloads may adapt native
signatures but do not copy execution, validation, ownership or error handling.
Deduplication is reviewed by concept and all its consumers, across package
boundaries. When two mechanisms turn out to be the same, migrate every consumer
and delete the redundant one. The [overview](overview.md#shared-mechanisms) lists
the current owners.

## Preserve types, ownership and origins

Operations keep the native payload types, typed errors, origins and resource
constraints of their inputs. Unsafe lifetime erasure, implicit dynamic boxing,
runtime registries, erased callback storage and hidden consumption are not used
to make an API more convenient. When sharing code would weaken one of these
guarantees, the code stays separate and the reason is written next to it.

## Observable behavior is specified

For every operation the documentation states evaluation order, laziness, how
often each callback runs, short-circuiting, failure behavior, and what is
borrowed, copied, moved or destroyed. [Ownership and errors](../start/ownership.md)
gives the shared conventions; each reference chapter states the specifics.

Callbacks are not required to be pure. Internal mutation is allowed when the
documented observable behavior is preserved. Algebraic laws hold under stated
purity and termination assumptions (see [laws](laws.md)).

## Measured performance

Efficiency is a requirement, but the library makes no universal zero-overhead
claim. A performance statement names the implementation, target, compiler and
measurement behind it. Compile time is treated as a cost like run time and
[measured cold](../contributing/benchmarks.md#measuring-compile-time).

## Scope

In scope: callable composition and partial application, sequential folds and
lazy iteration, typed results, algebraic data with exhaustive matching and
elimination, recursion over finite acyclic data evaluated in a loop, functional
control flow, a small algebra with
effect transformers, documented laws, and device-compatible specializations of
the non-allocating, non-raising core.

Out of scope: automatic currying, persistent collections, optics, memoization,
asynchronous effects, implicit parallelism, a distributed runtime, a GPU kernel
framework, open-world runtime class matching, regular-expression matching,
iterator backtracking, dependent pattern matching, proof checking and automatic
termination proofs. Conveniences such as `partial_right`, `curry`, `juxt` and
predicate combinators wait until the core callable contracts settle.

Some words have deliberately narrow meanings here:

- **Partial application** binds a positional prefix of a native function. It
  does not reproduce Python's keyword binding, placeholders, object identity or
  introspection.
- **Generic** means one algorithm specialized over compatible types and
  callables, not an untyped container that holds any runtime type.
- **GPU-compatible** means a specialization is usable inside a device context.
  It does not imply implicit data transfer, automatic kernel launch or
  reordering a sequential fold.

## Compiler pin

The library is pinned to one exact compiler, **Mojo 1.1.0 (8189361e)**, through
Pixi. The supported range grows only after the full verification gates pass on
a new compiler. Checking a newer compiler for new features or breakage never
silently changes the compiler used to qualify a release. The upgrade procedure is
in [native Mojo boundaries](native-boundaries.md#upgrading-the-compiler).
