"""Generate native signature boundaries; existing owners retain storage and effects."""

from pathlib import Path

from native_signatures import (
    native_dispatch,
    NATIVE_INVOCATIONS,
    native_factories,
)

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/fp/callables/native.mojo"
ADAPTER_START = "# --- native unary admission (generated) ---\n"
ADAPTER_END = "# --- end native unary admission ---\n"

def markers(name):
    indent = "        " if NATIVE_INVOCATIONS[name].view else "    "
    return (
        indent + f"# --- native invocation: {name} (generated) ---\n",
        indent + "# --- end native invocation ---\n",
    )


def body(name):
    invocation = NATIVE_INVOCATIONS[name]
    shape, types, values = invocation.shape, invocation.types, invocation.values
    keywords, view = invocation.keywords, invocation.view
    prefix = "Self." if view else ""
    prefix_body = ""
    if name in ("unary", "borrow"):
        prefix_body = register_void(types[0], values[0])
    return prefix_body + native_dispatch(
        shape,
        [prefix + t for t in types],
        values,
        keyword=prefix + "K" if keywords else None,
        keyword_value="values",
        result=prefix + "R",
        error=prefix + "E" if name != "binary" else "X",
        function_type=prefix + "F",
        function="self.function[]" if view else "function",
        raising=prefix + "raising",
        indent="        " if view else "    ",
    )


def register_void(payload, value):
    """Keep the specialized no-value register closure boundary in one place.

    Eager unary/borrowing callbacks share this rule. Lazy callbacks own mutable
    captures between pulls and keep their distinct receiver implementation.
    """
    return f"""    comptime if R == type_of(None) and conforms_to({payload}, TrivialRegisterPassable):
        comptime Arg = downcast[{payload}, TrivialRegisterPassable]
        comptime if raising and E == Never:
            comptime if F == def(Arg) raises Never thin or conforms_to(F, def(Arg) raises Never):
                _call_native_register_void[Arg, Never, F, True](function, rebind_var[Arg]({value}))
                return rebind_var[R](None)
        elif raising:
            comptime if F == def(Arg) raises E thin or conforms_to(F, def(Arg) raises E):
                _call_native_register_void[Arg, E, F, True](function, rebind_var[Arg]({value}))
                return rebind_var[R](None)
        else:
            comptime if F == def(Arg) thin or conforms_to(F, def(Arg)):
                _call_native_register_void[Arg, Never, F, False](function, rebind_var[Arg]({value}))
                return rebind_var[R](None)
"""


def unary_factories():
    out = [
        "# Preserve native pointer types and copyability. Register arguments and\n"
        "# results need explicit ABI evidence; symbolic forwards borrow a pointer\n"
        "# only for admission, then copy it into the existing NativeUnary owner.\n"
        "# No-value signatures must be admitted literally on Mojo 1.2.\n"
    ]
    for factory in native_factories("owned", ["A"]):
        parameters = [*factory.parameters, *factory.pointer.parameters]
        declarations = [name + ": " + bound for name, bound in parameters]
        conditions = factory.pointer.conditions
        where = " where " + " and ".join(conditions) if conditions else ""
        out += [
            f'def as_unary[{", ".join(declarations + ["//"])}](\n'
            f"    {factory.argument}\n"
            f") -> {factory.adapter}{where}:\n"
            '    """Store a native pointer with its exact signature and copyability."""\n'
            f"    return {factory.adapter}(function)\n\n\n"
        ]
    return "".join(out)


def source(text=None):
    text = OUTPUT.read_text() if text is None else text
    for name in NATIVE_INVOCATIONS:
        start, end = markers(name)
        before, remaining = text.split(start, 1)
        _, after = remaining.split(end, 1)
        text = before + start + body(name) + end + after
    before, remaining = text.split(ADAPTER_START, 1)
    _, after = remaining.split(ADAPTER_END, 1)
    text = before + ADAPTER_START + unary_factories() + ADAPTER_END + after
    return text.rstrip() + "\n"


if __name__ == "__main__":
    OUTPUT.write_text(source())
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
