# Maintaining the docs

This site is the project's documentation: its architecture, API contracts and
examples. There are no separate design documents; when a design decision
changes, the relevant page here changes with it.

## Build and review

```sh
pixi run docs-serve
pixi run docs-build
pixi run -e docs docs-check
pixi run docs-test --output .cache/docs-examples-001
```

The `docs` environment pins MkDocs 1.6.1 and Pygments 2.19.2; the default
environment keeps the pinned compiler. `docs-build` writes the static site to
`.cache/docs-site`. `docs-check` builds in strict mode and then checks every
rendered local link, anchor and asset, duplicate HTML ids, and that every API
chapter is in the search index. `docs-test` compiles and runs every example the
site includes. After visual changes, review desktop and mobile layouts, search,
keyboard focus, theme switching and printing in a browser.

For an example with expensive generic specialization, run it alone with
`pixi run docs-test --only <path> --compile-timeout 1800 --jobs 1 --output <dir>`;
the timeout and worker count are recorded in the report.

## Where things live

| Path | Contents |
|---|---|
| `mkdocs.yml` | Site configuration and navigation |
| `docs/content/` | The pages, in Markdown |
| `docs/examples/` | Every program the site includes |
| `docs/examples.json` | The expected standard output of each included program |
| `docs/public-exports.json` | The reviewed inventory of public names and their source modules |
| `docs/api.json` | The public API's docstrings, extracted by `python scripts/api_docs.py` |
| `docs/hooks.py` | MkDocs hooks: runs the documentation audit, expands directives and publishes source downloads |
| `docs/theme/` | The theme: `main.html` and `404.html` templates, `assets/` with styles, scripts, favicon and bundled fonts with their licenses |
| `scripts/docs_contract.py` | The audit and directive rendering, shared by the hooks and the tooling tests |

## Directives

Pages include generated material with HTML-comment directives:

```text
<!-- api: functions -->
<!-- example: docs/examples/quickstart.mojo -->
<!-- source: docs/examples/device/core.mojo -->
```

- `api` with a package name renders the package's reference from its
  docstrings, extracted into `docs/api.json` by `python scripts/api_docs.py`:
  the package docstring, a summary table, then every public name with its
  signature, description, limitations, parameters, arguments, result and error.
- `example` renders a complete program with its download link, run command and
  expected output. The program must be listed in `docs/examples.json`.
- `source` renders a file from `docs/examples/` that is not run on its own, such
  as a module or a GPU program.

Directives inside fenced code blocks are left alone. Directives never run library
code while the site builds.

## Rules the audit enforces

The build fails unless:

- every page starts with a `# ` title;
- no page contains a hand-written ` ```mojo ` block: include maintained files so
  readers see exactly what was tested (use `text` fences for signatures and
  sketches);
- the `api` directives name every public package exactly once, so every public
  name is documented once;
- `docs/api.json` covers exactly the reviewed public names, and every public
  name has a summary, and its documented overloads describe every parameter,
  argument, result and error;
- the set of `example` directives equals the set of programs in
  `docs/examples.json`, and each expected output ends with a newline;
- every `source` directive names a `.mojo` file in `docs/examples/`.

In docstrings, put code in backticks: an unbackticked `name[X](args)` renders
as a broken Markdown link.

## Documenting an API

The docstrings are the API documentation. A package docstring opens its page
with the package's shared contracts; each public name's docstring starts with a
one-line summary, then the description, an optional `Limitations:` block, and
the `Parameters:`, `Args:`, `Returns:` and `Raises:` sections. Fully document
at least one overload of each function; the others need a summary line and are
listed collapsed. Together they state, as it applies:

- purpose and exact signature;
- its relationship to Mojo's native capabilities (what it reuses, what gap it
  fills);
- type constraints;
- ownership: what is borrowed, copied, moved and destroyed;
- evaluation order, laziness and short-circuiting;
- errors, and the empty-input and no-match behavior;
- complexity, allocation and stack behavior;
- target support;
- the laws it satisfies and their assumptions.

When an API changes, review the new inventory from
`export_contract.export_inventory()` (in `scripts/`) and write it to
`docs/public-exports.json`; the build rejects any unreviewed difference. Then
update the docstrings, run `python scripts/api_docs.py` to refresh
`docs/api.json`, and add or update examples. Never regenerate expected outputs
from a failing implementation: review them independently.

## Adding an example

1. Write a complete program in `docs/examples/` with a `main` that asserts its
   results with `std.testing`, and a one-line docstring.
2. Add its path and exact expected output to `docs/examples.json`.
3. Include it on the page it illustrates with an `example` directive, and list it
   in the [example gallery](../examples/index.md).
4. Run `docs-test` for it and `docs-check`.

Every file in `docs/examples/` is also part of the `test` suite.

## Theme

The theme is a small custom MkDocs theme: Jinja templates for the page shell,
navigation and search page, a stylesheet and scripts for theme switching, mobile
navigation and search, and the Catppuccin/Material color variables it builds on.
Fonts are bundled, so the site makes no external requests; search uses MkDocs'
generated index with its bundled Lunr. Keep URLs relative so the site works under
any path. See MkDocs' [theme guide](https://www.mkdocs.org/dev-guide/themes/) and
[configuration reference](https://www.mkdocs.org/user-guide/configuration/).

The minimal program used on the home page is also the smallest example of the
directive format:

<!-- example: docs/examples/quickstart.mojo -->
