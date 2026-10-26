"""Generate Partial's native prefix arities, retaining its copy-on-call policy.

Capture consumes argument bundles; Partial repeatedly copies its bound prefix.
Only native convention spelling is shared. Pack signatures remain distinct from
fixed-arity callable signatures and keep their existing inference parameters.
"""

from pathlib import Path

from generate_plain_overloads import splice_source
from native_signatures import MD, argument

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/fp/functions/partial.mojo"
MAX_BOUND = 8
PARAMETERS = (
    f"R: {MD}, E: {MD}, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]"
)
WORDS = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight")

BIND_DOC = '''
    """Bind a plain function's first argument; call the result with the rest.

    `partial(f, a)(b, c)` calls `f(a, b, c)`. The overloads bind zero to eight
    leading arguments, as in `partial(f, a, b)`. Construction copies each bound
    argument once and never calls `f`; every call passes `f` fresh copies, and
    the remaining arguments are borrowed. The result keeps `f`'s error type.

    Limitations:
        `f` must be a plain function (no captures) whose remaining parameters
        are read, not owned or `mut`; bound values must be `Copyable`; and a
        `Partial` cannot be the target of another `partial`. Keyword binding,
        reordering and the other cases are written as a closure.

    Parameters:
        A0: The bound argument's type; it must be `Copyable`.
        R: The function's result type.
        E: The function's error type, `Never` for a pure function.
        Rs: The types of the remaining parameters.

    Args:
        function: The plain function.
        a0: The value to bind, copied.

    Returns:
        A `Partial` that calls `function(a0, rest...)`.
    """
'''


def markers(section):
    indent = "        " if section == "invocation" else ""
    return (
        indent + f"# --- partial {section} (generated) ---\n",
        indent + f"# --- end partial {section} ---\n",
    )


def native_signature(types):
    # Bound prefix parameters are owned; remaining arguments are a read pack.
    # These abstract types retain the original pack ABI without register casts.
    operands = [
        argument(f"a{i}: {t}", "o", thin=True, known=False) for i, t in enumerate(types)
    ]
    return "def(" + ", ".join([*operands, "*args: *Rs"]) + ") raises E thin -> R"


def copies(values):
    return ", ".join(value + ".copy()" for value in values)


def signatures():
    rows = [
        f"comptime _Fn{n}[{PARAMETERS}] = {native_signature([f'Bs[{i}]' for i in range(n)])}\n"
        for n in range(MAX_BOUND + 1)
    ]
    alternatives = [
        f"_Fn{n}[R, E, Bs, Rs] if Bs.length == {n} else" for n in range(MAX_BOUND)
    ]
    rows.append(
        f"comptime _Fn[{PARAMETERS}] = (\n    "
        + "\n    ".join(alternatives)
        + f" _Fn{MAX_BOUND}[R, E, Bs, Rs]\n)\n"
    )
    return "".join(rows)


def invocation():
    rows = []
    for n in range(MAX_BOUND + 1):
        clause = (
            "comptime if n == 0"
            if n == 0
            else "else" if n == MAX_BOUND else f"elif n == {n}"
        )
        rows.append(f"        {clause}:\n")
        if n == MAX_BOUND:
            rows.append(
                f'            comptime assert n == {MAX_BOUND}, "partial: at most {MAX_BOUND} bound arguments"\n'
            )
        prefix = copies([f"b[{i}]" for i in range(n)])
        args = prefix + ", *rest" if prefix else "*rest"
        rows.append(
            f"            return rebind[_Fn{n}[Self.R, Self.E, Self.Bs, Pack]](self.function)({args})\n"
        )
    return "".join(rows)


def overloads():
    rows = []
    for n in range(MAX_BOUND + 1):
        types = [f"A{i}" for i in range(n)]
        parameters = [
            *[f"{t}: _Bound" for t in types],
            f"R: {MD}",
            f"E: {MD}",
            "Rs: TypeList[Trait=_Rest, ...]",
            "//",
        ]
        args = [
            "function: " + native_signature(types),
            *[f"a{i}: {t}" for i, t in enumerate(types)],
        ]
        bound = ", ".join(["Trait=_Bound", *types])
        summary = (
            "Store a native function without binding arguments."
            if n == 0
            else f"Bind the first {WORDS[n]} arguments."
        )
        doc = BIND_DOC.strip("\n") if n == 1 else f'    """{summary}"""'
        rows.append(
            f"def partial[{', '.join(parameters)}](\n    {', '.join(args)}\n) -> Partial[R, E, TypeList.of[{bound}](), Rs]:\n"
            + doc
            + "\n"
            + "    return {function, Tuple("
            + copies([f"a{i}" for i in range(n)])
            + ")}\n"
        )
    return "\n\n".join(rows)


def source():
    text = OUTPUT.read_text()
    for section, render in (
        ("signatures", signatures),
        ("invocation", invocation),
        ("overloads", overloads),
    ):
        start, end = markers(section)
        indent = "        " if section == "invocation" else ""
        text = splice_source(
            text,
            render(),
            start,
            end,
            indent + "# Generated by scripts/generate_partial.py.\n",
        )
    return text


if __name__ == "__main__":
    OUTPUT.write_text(source())
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
