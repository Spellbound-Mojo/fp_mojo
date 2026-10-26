"""Generate native signature boundaries; existing owners retain storage and effects."""

from pathlib import Path

from native_signatures import (
    MD,
    Operand,
    argument,
    factory_pointer,
    native_dispatch,
    native_adapter,
    variants,
)

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/fp/callables/native.mojo"
ADAPTER_START = "# --- native unary admission (generated) ---\n"
ADAPTER_END = "# --- end native unary admission ---\n"

# These are the existing invocation owners. Capture delegates matching shapes
# here and uses the same emitter for its remaining mixed-convention bundles.
VIEWS = {
    "thunk": ("", [], [], False, False),
    "unary": ("o", ["A"], ["value"], False, False),
    "borrow": ("r", ["P"], ["payload"], False, False),
    "binary": ("oo", ["A", "B"], ["first", "second"], False, False),
    "keywords": ("", [], [], True, False),
    "mutating": ("m", ["A"], ["value"], False, True),
    "mut_owned": ("mo", ["A", "B"], ["first", "second"], False, True),
    "mutating_keywords": ("m", ["A"], ["first"], True, True),
    "mut_owned_keywords": ("mo", ["A", "B"], ["first", "second"], True, True),
}


def markers(name):
    indent = "        " if VIEWS[name][-1] else "    "
    return (
        indent + f"# --- native invocation: {name} (generated) ---\n",
        indent + "# --- end native invocation ---\n",
    )


def body(name):
    shape, types, values, keywords, view = VIEWS[name]
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
    operand = Operand("A", "o", known=False)
    for raising in (False, True):
        for void in (False, True):
            for abi in variants([operand], None if void else "R"):
                pointer = factory_pointer(abi)
                parameters = list(abi.parameters)
                if raising:
                    parameters += [("E", MD)]
                parameters += pointer.parameters
                declarations = [name + ": " + bound for name, bound in parameters]
                signature = (
                    "def("
                    + argument("A", "o", thin=True, known=False)
                    + ")"
                    + (" raises E" if raising else "")
                    + " thin"
                    + ("" if void else " -> R")
                )
                result = "type_of(None)" if void else "R"
                error = "E" if raising else "Never"
                target = native_adapter(
                    "owned", ["A"], result, error, "type_of(function)", raising
                )
                where = (
                    " where " + " and ".join(pointer.conditions)
                    if pointer.conditions
                    else ""
                )
                out += [
                    f'def as_unary[{", ".join(declarations + ["//"])}](\n'
                    f"    {pointer.argument}: {signature}\n"
                    f") -> {target}{where}:\n"
                    '    """Store a native pointer with its exact signature and copyability."""\n'
                    f"    return {target}(function)\n\n\n"
                ]
    return "".join(out)


def source(text=None):
    text = OUTPUT.read_text() if text is None else text
    for name in VIEWS:
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
