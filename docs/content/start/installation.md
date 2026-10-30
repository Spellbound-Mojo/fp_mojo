# Installation and first run

Use a `nightly` source checkout for the current tutorials and API. The released
package remains available for existing Mojo 1.1 projects.

The `nightly` development checkout pins Mojo 1.2.0 and Python 3.14 through
[Pixi](https://pixi.sh). The published FP Mojo 1.0.0 package still requires
Mojo 1.1.0, with which it was verified on Linux x86-64 and macOS arm64.
Use the [checkout route](#work-from-a-checkout) for Mojo 1.2; the published
package cannot yet be installed with that compiler. The verified nightly Linux
checkpoint passes the full positive and rejection suites. See the
[compatibility inventory](../guides/compatibility.md) for the qualified source
commit, platform limits and legacy invalid-call inference restrictions.

## Work from a checkout

Install Pixi if it is missing and put it on your `PATH`:

```sh
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="$HOME/.pixi/bin:$PATH"
```

Then clone the repository, install the locked environment and run the
quickstart:

```sh
git clone --branch nightly https://github.com/Spellbound-Mojo/fp_mojo.git
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

The package lives in `src/fp`. Pass `-I src` so imports such as
`from fp.functions import pipe` resolve. Import each name from the package that
owns it. The package root `fp` re-exports only `match`, `rewrite` and `when`, so
`import fp` is enough to write `fp.match(...)`.

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

This alternative installs the published FP Mojo 1.0.0 release for Mojo 1.1.
Use the checkout above for the current tutorial API.

Install [Pixi](https://pixi.sh) if it is not already on your `PATH`. Then create
a project with the Mojo and
[Modular community](https://github.com/modular/modular-community) channels:

```sh
pixi init fp-start \
  --channel https://conda.modular.com/max \
  --channel https://repo.prefix.dev/modular-community \
  --channel conda-forge
cd fp-start
pixi add fp_mojo "mojo==1.1.0"
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

Then run `pixi add fp_mojo "mojo==1.1.0"` in that project and save the same
program beside its `pixi.toml`.

### Run the tutorial examples

The current tutorials use the nightly API, including `pipeline`, Result
terminals and `.elements()`. Follow the [checkout route](#work-from-a-checkout)
and run their maintained files from the repository root:

```sh
pixi run mojo run -I src docs/examples/combinators.mojo
```

Each example's frame includes the corresponding command and a Download link.
The released-package quickstart above retains the original `pipe` API; it does
not require the new nightly operations.

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

## Async preview from nightly

The pure-Mojo async preview is available from the pinned Mojo 1.2 checkout on
Linux x86-64. Import `fp.effects.async_runtime` for `IO` and host
execution, or `fp.effects.async_runtime.protocols` for custom machines. The
released Mojo 1.1 package does not contain this preview. Follow the
[async guide](../guides/async-runtime.md) for executable examples and boundaries.
