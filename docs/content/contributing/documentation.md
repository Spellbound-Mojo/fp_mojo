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

## Writing style

Use the [home page](../index.md) opening as a model. Write as you would explain
the library to another programmer: introduce a task or concept, show how it
works, then explain the choices and limits that matter.

- Use established functional programming terms: composition, partial
  application, folds, algebraic data types, inductive data types, exhaustive
  pattern matching and monad transformers. Explain a term through its use;
  for example, `Result` is a sum type with `Ok` and `Err` constructors, and
  `flat_map` is monadic bind that skips the callback on `Err`.
- Keep terminology precise. A non-raising callback can still mutate state;
  call it pure only when purity is the property being discussed. Explain an
  inductive type through its finite constructor-built values and structural
  recursion.
- Prefer direct verbs and familiar words. Replace promotional claims with an
  example or a precise contract. Leave out "please", "simply" and bold
  warnings; state a limit once, plainly.
- Walk through an example with its own values: `positive(-1)` returns `Err`, so
  `twice` never runs.
- Say what an operation borrows, copies, moves or destroys, when its callbacks
  run, and how often.
- Keep the failure channels apart: a stored `Err`, a raised error, a match with
  no applicable clause, and iterator exhaustion. State whether a rule applies to
  a callback, an operation, or a whole pipeline or match.
- Give limits where they affect a reader's choice: callback forms, arities,
  ownership conventions, compilers and targets. Keep planned features separate
  from implemented ones.
- Use tables for comparisons and lists for steps or parallel choices. Use
  paragraphs for explanations that build on one another.
- Vary sentences to fit their subject. Avoid repeating a stock opening on every
  page or turning every explanation into a list of bold claims. Keep an example's
  walkthrough focused on what its values and callbacks actually do.
- Keep proofs, compiler workarounds and benchmark evidence in the architecture
  pages. Preserve assumptions, measurement conditions and the meaning of each
  ratio.

Organize a page around what its reader needs:

| Page | Shape |
|---|---|
| Tutorial chapter | Introduce the concept, show a maintained example, and explain its results. Link to the next chapter and put compiler implementation details in the architecture pages. |
| Reference page | Help the reader choose an operation, then include the `api` directive and relevant examples. Keep the introduction distinct from the generated package docstring. |
| Architecture chapter | The contract, then how the implementation meets it and why; limits and their sources |
| Guide | Explain a task or decision. Use a table when the reader needs to compare choices or look up a symptom. |

Address the reader as "you", and avoid "we". Name headings after a task or a
claim, such as "Transform only the active branch", rather than "Example" or
"Discussion".

## Where decisions go

- A package's contract and the reasons for its design go in its architecture
  chapter.
- Compiler limitations go in [native Mojo boundaries](../architecture/native-boundaries.md).
- Measurements go in [performance](../architecture/performance.md); the
  workflows that produce them go in [development](development.md) or
  [benchmarks](benchmarks.md).
- What is supported today and what is planned goes in
  [support and limitations](../guides/status.md).
- Describe current behavior, and label any historical measurement with its
  setup.

## Where things live

| Path | Contents |
|---|---|
| `mkdocs.yml` | Site configuration and navigation |
| `docs/content/` | The pages, in Markdown |
| `docs/examples/` | Every program the site includes |
| `docs/examples.json` | The expected standard output of each included program |
| `docs/public-exports.json` | The reviewed inventory of public names and their source modules |
| `docs/api.json` | The public API's docstrings, extracted by `python scripts/api_docs.py` |
| `docs/hooks.py` | MkDocs hooks: reads the version from `pixi.toml`, runs the documentation audit, expands directives and publishes source downloads |
| `docs/theme/` | The theme: `main.html` and `404.html` templates, `assets/` with styles, scripts, favicon and bundled fonts with their licenses |
| `scripts/docs_contract.py` | The audit and directive rendering, shared by the hooks and the tooling tests |

## Directives

Pages include generated material with HTML-comment directives:

```text
<!-- api: functions -->
<!-- example: docs/examples/quickstart.mojo -->
<!-- source: docs/examples/<file>.mojo -->
```

- `api` with a package name renders the package's reference from its
  docstrings, extracted into `docs/api.json` by `python scripts/api_docs.py`:
  the package docstring, a summary table, then every public name with its
  signature, description, limitations, parameters, arguments, result and error.
- `example` renders a complete program as one frame: its file name and download
  link, the code, the run command and the expected output. The program must be
  listed in `docs/examples.json`. The output has no copy button: it is read, not
  pasted.
- `source` renders a file from `docs/examples/` without a run command or output.
  Use it for a module, or when a page supplies its own run instructions, as in
  the installed-package quickstart. Runnable programs still belong in the
  example manifest and need an `example` inclusion elsewhere on the site.

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
navigation and search page, one stylesheet (`assets/site.css`), and scripts for
theme switching, mobile navigation, copy buttons and search. Fonts are bundled,
so the site makes no external requests; search uses MkDocs' generated index with
its bundled Lunr. Keep URLs relative so the site works under any path.

The header shows the version from `pixi.toml` and links to its GitHub release;
the sidebar and footer name the Mojo series from the `mojo` dependency. Both are
read at build time, so bumping the version at a release updates the site.

`site.css` defines every color as a token on `:root.light` and `:root.dark`; the
rest of the stylesheet uses only the tokens. Syntax colors follow Catppuccin:
Latte hues, deepened for contrast, in the light theme and Mocha in the dark.
Keywords are purple, types amber, functions blue, modules teal, strings green,
numbers and constants orange, decorators pink, `self` red, operators sky and
comments grey italic. Prose is limited to about 74 characters a line; code and
tables use the full column. See MkDocs' [theme guide](https://www.mkdocs.org/dev-guide/themes/) and
[configuration reference](https://www.mkdocs.org/user-guide/configuration/).

The minimal program used on the home page is also the smallest example of the
directive format:

<!-- example: docs/examples/quickstart.mojo -->
