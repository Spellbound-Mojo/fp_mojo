# Installation and first run

Install `fp_mojo` in a Pixi project, or run the library from a source checkout.
Both routes use the same imports, such as `from fp.functions import pipe`.

FP Mojo is verified with Mojo 1.1.0 on Linux x86-64 and macOS arm64. The steps
below select that compiler. The development checkout also pins Python 3.14
through [Pixi](https://pixi.sh).

## Install the package

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

Each example on the site has a Download link. Save the file in your Pixi
project and run it by name, for example:

```sh
pixi run mojo run algebra_choices.mojo
```

The command shown inside an example's frame runs its maintained copy from a
repository checkout. Use the downloaded file's name, as above, when working
with the installed package.

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
pixi run mojo run -I src docs/examples/quickstart.mojo
```

The compiler reports `Mojo 1.1.0 (8189361e)` and the program prints `42`. Use
the project environment even if another Mojo is installed on your system.
Pixi downloads Mojo from `conda.modular.com`; where that host is unreachable, the
PyPI wheel `mojo==1.1.0` is the same compiler build.

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
