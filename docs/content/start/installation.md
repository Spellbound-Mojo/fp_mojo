# Installation and first run

FP Mojo can be installed as a [precompiled package](#install-the-package) in an
existing Pixi project, or used directly from a [source checkout](#work-from-a-checkout).
FP Mojo 1.0.2 is qualified for Mojo 1.2.0; the repository source checkout pins
Mojo 1.2.0 and Python 3.14 through [Pixi](https://pixi.sh). For platform qualification,
release history, and compiler boundaries, see the [compatibility guide](../guides/compatibility.md)
and [support and limitations](../guides/status.md).

## Work from a checkout

Install Pixi if it is missing and put it on your `PATH`:

```sh
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="$HOME/.pixi/bin:$PATH"
```

Then clone the repository, install the locked environment and run the
quickstart:

```sh
git clone https://github.com/Spellbound-Mojo/fp_mojo.git
cd fp_mojo
pixi install --locked
pixi run mojo --version
pixi run mojo run -I src docs/examples/pipeline_quickstart.mojo
```

The compiler reports `Mojo 1.2.0 (2016d0cd)` and the program prints `42`. Use
the project environment even if another Mojo is installed on your system.
Pixi downloads Mojo from `conda.modular.com`. The optional `device` environment
uses MAX 26.7.0, whose compiler dependency matches Mojo 1.2.0.

## Import from source

The library sources reside in `src/fp`. Supply `-I src` when invoking the compiler
so module paths resolve cleanly. The root `fp` package re-exports the primary
prelude, enabling most programs to start with a concise import:
`from fp import pipeline, iterated, Result, Ok, Err, Capture, map, filter`.

The top-level prelude also exposes `pipeline_values`, `flow`, `partial`, `flat_map`,
`traverse`, `sequence`, `fold_map`, `combine_all`, `sum_by`, `find_map`, canonical
monoids (`StringMonoid`, `ListMonoid`, `IntSumMonoid`, `IntProductMonoid`),
`Accumulate`, `ValidationFamily`, `match`, `when`, and `rewrite`.

The operations `map` and `filter` at the root represent eager transformations
(`fp.algebra`); for lazy zero-allocation pipelines, use `iterated(source).map(...)`
or `fp.iteration`. Pure and asynchronous effects are organized under `fp.effects`
and `fp.effects.async_runtime`. To inspect algebraic data types, `import fp` suffices
to invoke `fp.match(...)`.

```sh
pixi run mojo run -I src docs/examples/callable_pipeline.mojo
```

To build an executable, choose the optimization level explicitly:

```sh
mkdir -p .cache/local
pixi run mojo build -I src -O3 --Werror docs/examples/quickstart.mojo -o .cache/local/quickstart
.cache/local/quickstart
```

`--Werror` turns warnings into errors. Programs written for a different Mojo
version may not compile on the pinned one.

## Import a precompiled package

A precompiled package gives you the same API without compiling the sources on
every run:

```sh
mkdir -p .cache/local/package
pixi run mojo precompile -I src --Werror src/fp -o .cache/local/package/fp.mojoc
pixi run mojo run -I .cache/local/package docs/examples/quickstart.mojo
```

Rebuild the package after changing the library sources. `pixi run build` does the
same into a fresh directory and also runs an example against the result (see
[development](../contributing/development.md)).

## Install the package

FP Mojo 1.0.2, the release for Mojo 1.2, is published as `fp_mojo` in the
Modular community channel.

Install [Pixi](https://pixi.sh) if it is not already on your `PATH`. Then create
a project with the Mojo and
[Modular community](https://github.com/modular/modular-community) channels:

```sh
pixi init fp-start \
  --channel https://conda.modular.com/max \
  --channel https://repo.prefix.dev/modular-community \
  --channel conda-forge
cd fp-start
pixi add fp_mojo "mojo==1.2.0"
```

Run the remaining commands from `fp-start`, the directory containing the new
`pixi.toml`. Pixi installs the precompiled `fp` package where Mojo can find it,
so no source checkout or `-I` flag is needed.

Save the following program as `quickstart.mojo` beside `pixi.toml`, or use its
Download link and place the downloaded file there:

<!-- source: docs/examples/quickstart.mojo -->

Run it with:

```sh
pixi run mojo run quickstart.mojo
```

The program prints `42`. `pipe(21, twice)` passes 21 to `twice`, and the
assertion checks the result before printing it.

For an existing Pixi project, keep its current settings and add any missing
channels to its `[workspace]` section:

```toml
[workspace]
channels = ["https://conda.modular.com/max", "https://repo.prefix.dev/modular-community", "conda-forge"]
```

Then run `pixi add fp_mojo "mojo==1.2.0"` in that project and save the same
program beside its `pixi.toml`.

### Run the tutorial examples

The tutorials' maintained example files live in the repository. Follow the
[checkout route](#work-from-a-checkout) and run them from the repository root:

```sh
pixi run mojo run -I src docs/examples/combinators.mojo
```

Each example's frame includes the corresponding command and a Download link.

## Build this documentation site

MkDocs lives in a separate locked `docs` environment:

```sh
pixi install --locked -e docs
pixi run docs-serve
```

Open the address MkDocs prints. `pixi run docs-build` writes the static site to
`.cache/docs-site`, and `pixi run docs-check` also audits its links, anchors and
search index.

Next, read [ownership and errors](ownership.md) or start the
[pipeline tutorial](../tutorial/pipelines.md).

## Structured async runtime

FP Mojo 1.0.2 includes a pure-Mojo structured asynchronous runtime supporting
Linux x86-64 and macOS arm64. Import `fp.effects.async_runtime` (or `fp.effects`)
for `IO`, lightweight cancelable fibers, and host runners. The multi-threaded
work-stealing pool targets 64-bit Linux, while single-threaded execution and
deterministic virtual-time testing via `TestControl` run on both macOS and Linux.
Follow the [async runtime guide](../guides/async-runtime.md) for architectural
guidance, concurrency primitives, and runnable examples.
