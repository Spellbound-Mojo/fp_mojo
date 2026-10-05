# Installation and first run

You can add FP Mojo to a Pixi project as the `fp_mojo` package, or work from a
checkout of the repository and pass `-I src` to the compiler. Either way,
`from fp.functions import pipe` then imports the library. FP Mojo works with
Mojo 1.1.x and is verified on Linux x86-64 and macOS arm64; the development
environment pins Mojo 1.1.0 and Python 3.14 through [Pixi](https://pixi.sh).

## Install the package

FP Mojo is published as `fp_mojo` in the
[Modular community channel](https://github.com/modular/modular-community). Add the
channel to your project's `pixi.toml`:

```toml
[workspace]
channels = ["https://conda.modular.com/max", "https://repo.prefix.dev/modular-community", "conda-forge"]
```

Then add the package. It installs the precompiled `fp` package where Mojo finds
it, so you do not need an `-I` flag:

```sh
pixi add fp_mojo
pixi run mojo run my_program.mojo
```

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
