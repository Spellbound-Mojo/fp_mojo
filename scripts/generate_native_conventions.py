"""Generate native signature boundaries; existing owners retain storage and effects."""

from pathlib import Path

from native_signatures import (
    MD,
    native_dispatch,
    NATIVE_INVOCATIONS,
    native_factories,
    native_adapter,
    variants,
    Operand,
)

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/fp/callables/native.mojo"
RESOURCE_OUTPUT = ROOT / "src/fp/effects/effectful_resources.mojo"
RESOURCE_START = "    # --- resource callback admission (generated) ---\n"
RESOURCE_END = "    # --- end resource callback admission ---\n"
PROJECTION_OUTPUT = ROOT / "src/fp/effects/projections.mojo"
PROJECTION_START = "# --- native projection pointers (generated) ---\n"
PROJECTION_END = "# --- end native projection pointers ---\n"
SCOPED_OUTPUT = ROOT / "src/fp/effects/scoped.mojo"
SCOPED_START = "# --- native scoped IO pointers (generated) ---\n"
SCOPED_END = "# --- end native scoped IO pointers ---\n"
ADAPTER_START = "# --- native unary admission (generated) ---\n"
ADAPTER_END = "# --- end native unary admission ---\n"
BINARY_START = "# --- native binary admission (generated) ---\n"
BINARY_END = "# --- end native binary admission ---\n"
CAPTURE_START = "    # --- native binary capture (generated) ---\n"
CAPTURE_END = "    # --- end native binary capture ---\n"
BORROW_CAPTURE_START = "    # --- native borrow capture (generated) ---\n"
BORROW_CAPTURE_END = "    # --- end native borrow capture ---\n"

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
    header = (
        "# Preserve native pointer types and copyability. Register arguments and\n"
        "# results need explicit ABI evidence; symbolic forwards borrow a pointer\n"
        "# only for admission, then copy it into the existing NativeUnary owner.\n"
        "# No-value signatures must be admitted literally on Mojo 1.2.\n"
    )
    return header + pointer_factories("owned", ["A"], "as_unary")


def pointer_factories(mode, payloads, name, *, owner=None):
    out = []
    for factory in native_factories(mode, payloads, owner=owner):
        parameters = [*factory.parameters, *factory.pointer.parameters]
        declarations = [name + ": " + bound for name, bound in parameters]
        conditions = factory.pointer.conditions
        where = " where " + " and ".join(conditions) if conditions else ""
        out += [
            f'def {name}[{", ".join(declarations + ["//"])}](\n'
            f"    {factory.argument}\n"
            f") -> {factory.adapter}{where}:\n",
            ('    """Store a native pointer with its exact signature and copyability."""\n'
             if mode == "owned" else BINARY_DOC.format(parameters="".join(
                 f"        {parameter}: {BINARY_PARAMETERS[parameter]}\n"
                 for parameter, _ in parameters))),
            f"    return {factory.adapter}(function)\n\n\n"
        ]
    return "".join(out)


BINARY_DOC = '''    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
{parameters}

    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
'''

BINARY_PARAMETERS = {
    "A": "The first owned argument's type.",
    "B": "The second owned argument's type.",
    "R": "The result type.",
    "E": "The native error type.",
    "q": "The temporary admission borrow's origin, not stored in the adapter.",
}


def capture_methods(mode):
    """Admit a closure after its complete native signature has been selected."""
    payloads, native_inputs, pure, effect, public_owner = {
        'binary': (['Self.A', 'Self.B'], 'var Self.A, var Self.B', '_Binary', '_RaisingBinary', 'NativeBinary'),
        'borrow': (['Self.A'], 'Self.A', '_Borrowing', '_RaisingBorrowing', 'NativeBorrow'),
    }[mode]
    out = []
    for effect_kind in ('pure', 'never', 'typed'):
        raising = effect_kind != 'pure'
        for void in (False, True):
            failure = "Self.E" if effect_kind == 'typed' else "Never"
            if void or effect_kind == 'never':
                bound = "def(" + native_inputs + ")" + (" raises " + failure if raising else "")
                if not void:
                    bound += ' -> Self.R'
            else:
                bound = (effect if raising else pure) + '[' + ', '.join(
                    [*payloads, 'Self.R', *(['Self.E'] if raising else [])]) + ']'
            conditions = ["Self.E != Never" if effect_kind == 'typed' else "Self.E == Never"] + [
                "Self.R " + ("==" if void else "!=") + " type_of(None)"]
            owner = native_adapter(mode, payloads, 'Self.R', failure, 'F', raising, owner=public_owner)
            out.append(f'''    @staticmethod
    def capture[F: {bound}](var function: F) -> {owner} where {" and ".join(conditions)}:
        """Capture a callback with the selected signature without invoking it.

        Parameters:
            F: The callback's exact native type, inferred at this boundary.

        Args:
            function: The callback, moved into the adapter with its captures.

        Returns:
            A `{public_owner}` preserving the callback's types and ownership.
        """
        return {owner}(function^)

''')
    return "".join(out)


def borrow_capture_pointers():
    """Match the complete pointer type after selecting its native ABI.

    Matching a spelled pointer argument loses aliases in Mojo 1.2. Keep F
    intact and compare it to the selected signature instead. Fresh bounded
    parameters, defaulted from the selection, retain register ABI evidence;
    projecting a type inside the native signature loses that evidence.
    Borrowing only admits/copies a pointer and does not retain its origin.
    """
    out = []
    for effect_kind in ('pure', 'never', 'typed'):
        raising = effect_kind != 'pure'
        failure = 'Self.E' if effect_kind == 'typed' else 'Never'
        for void in (False, True):
            for abi in variants([Operand('Self.A', 'r', read_parameter='B')], None if void else 'S'):
                parameters = [('F', 'Copyable & Deinitable'), ('q', 'ImmOrigin')]
                declarations = [f'{name}: {bound}' for name, bound in parameters]
                for name, bound in abi.parameters:
                    selected = 'Self.A' if name == 'B' else 'Self.R'
                    default = f'downcast[{selected}, {bound}]' if 'RegisterPassable' in bound else selected
                    declarations.append(f'{name}: {bound} = {default}')
                signature = f'def({abi.payloads[0]})' + (' raises ' + failure if raising else '') + ' thin' + ('' if void else ' -> S')
                owner = native_adapter('borrow', ['Self.A'], 'Self.R', failure, 'F', raising, owner='NativeBorrow')
                guards = [condition.replace('conforms_to(S,', 'conforms_to(Self.R,') for condition in abi.conditions]
                guards += [f'conforms_to({"Self.A" if name == "B" else "Self.R"}, {"TrivialRegisterPassable" if name == "B" else "RegisterPassable"})'
                           for name, bound in abi.parameters if 'RegisterPassable' in bound]
                conditions = [f'F == ({signature})', *guards,
                              'Self.E != Never' if effect_kind == 'typed' else 'Self.E == Never',
                              'Self.R ' + ('==' if void else '!=') + ' type_of(None)',
                              *([] if void else ['S == Self.R'])]
                descriptions = dict(F="The pointer's exact native type, inferred without expanding aliases.",
                                    q='The temporary pointer admission borrow, not stored in the adapter.',
                                    B='The selected register input, defaulted from the payload type.',
                                    S='The selected native result, defaulted from the result type.')
                documented = ''.join(f'            {name}: {descriptions[name]}\n' for name, _ in [*parameters, *abi.parameters])
                out.append(f'''    @staticmethod
    def capture[{", ".join(declarations)}](ref[q] function: F) -> {owner} where {" and ".join(conditions)}:
        """Store a thin pointer with the selected read-only signature.

        Parameters:
{documented}
        Args:
            function: The native pointer, copied into the existing callback owner.

        Returns:
            A `NativeBorrow` preserving the pointer's exact signature.
        """
        return {owner}(function.copy())

''')
    return ''.join(out)


def reader_parameters(factory, result):
    """Keep the inferred action witness and its native result ABI together."""
    bounds = {MD: "ReaderAction", "RegisterPassable & Deinitable": "ReaderAction & RegisterPassable"}
    return [f"{p}: {bounds[bound] if p == result else bound}" for p, bound in factory.parameters]


def resource_callbacks():
    """Adapt owned callbacks and copied thin pointers to one scoped IO owner."""
    out = []
    for name, projection in (("use", "Used"), ("eval_map", "EvalMapped"), ("eval_tap", "EvalTapped")):
        def emit(parameters, argument, adapter, build, conditions, description, *, program=None):
            factory = f"_ScopedFactory[{adapter}" + (", " + program if program else "") + "]"
            result = f"Self.{projection}[{factory}]"
            admission = [*conditions, f"_ScopedFactoryCompatible[{adapter}]",
                         f"Self.ScopedCompatible[{factory}]"]
            out.append(f'''\n    def {name}[{", ".join(parameters)}](deinit self, {argument}) -> {result} where {" and ".join(admission)}:
        """{description}"""
        return self^.{name}({build})
''')

        # Preserve the existing native parameter positions and ownership.
        emit([f"F: BorrowCallContract & {MD}"], "var function: F", "F",
             "_scoped_io(function^)", [],
             "Adapt an input-independent IO factory to the shared scoped runner.")
        for raising in (False, True):
            error = "X" if raising else "Never"
            parameters = ["P: AnyType", f"V: {MD}"] + ([f"X: {MD}"] if raising else [])
            bound = "_RaisingBorrowing[P, V, X]" if raising else "_Borrowing[P, V]"
            parameters += ["//", "F: " + bound]
            adapter = native_adapter("borrow", ["P"], "V", error, "F", raising)
            emit(parameters, "var function: F", adapter, adapter + "(function^)", [],
                 "Adapt a native borrowing IO factory without executing it.")

        # The resource fixes the input before native ABI inference. The shared
        # fallback borrows a symbolic pointer only for admission, then copies it;
        # no callback origin enters the resulting resource or IO program.
        for factory in native_factories("borrow", [Operand("Self.Value", "r", read_parameter="P")],
                                        result="V", error="X", include_void=False):
            parameters = reader_parameters(factory, "V")
            parameters += [f"{p}: {bound}" for p, bound in factory.pointer.parameters] + ["//"]
            adapter = factory.adapter
            emit(parameters, factory.argument, adapter,
                 f"_ScopedFactory[{adapter}, V]({adapter}(function))", factory.pointer.conditions,
                 "Copy a stored thin IO factory into the existing callback owner; execution stays deferred.", program="V")
    return "".join(out)


def projection_pointers():
    """Both public projection spellings delegate to the existing Project owner."""
    out = []
    for name in ("asks", "inspect"):
        for factory in native_factories("borrow", [Operand("I.Input", "r", read_parameter="P")]):
            parameters = [f"{p}: {bound}" for p, bound in [*factory.parameters, *factory.pointer.parameters]]
            parameters += ["//", "I: Project"]
            guards = [*factory.pointer.conditions, f"I.ProjectCompatible[{factory.adapter}]"]
            out.append(f'''def {name}[{", ".join(parameters)}]({factory.argument}) raises I.ProjectError[{factory.adapter}] -> I.Projected[{factory.adapter}] where {" and ".join(guards)}:
    """Copy a stored borrowing pointer into the selected projection; execution stays deferred."""
    return asks[I]({factory.adapter}(function))


''')
    return "".join(out)


def scoped_pointers():
    """Preserve the inferred IO action witness in the shared scoped adapter."""
    out = []
    for factory in native_factories("borrow", ["P"], include_void=False):
        parameters = reader_parameters(factory, "R")
        parameters += [f"{p}: {bound}" for p, bound in factory.pointer.parameters] + ["//"]
        guards = [*factory.pointer.conditions, f"_ScopedFactoryCompatible[{factory.adapter}]"]
        owner = f"_ScopedFactory[{factory.adapter}, R]"
        out.append(f'''def scoped_io[{", ".join(parameters)}]({factory.argument}) -> {owner} where {" and ".join(guards)}:
    """Copy a stored borrowing IO factory without invoking it or retaining its admission borrow."""
    return {owner}({factory.adapter}(function))


''')
    return "".join(out)


def projection_source(text=None):
    text = PROJECTION_OUTPUT.read_text() if text is None else text
    before, remaining = text.split(PROJECTION_START, 1)
    _, after = remaining.split(PROJECTION_END, 1)
    return before + PROJECTION_START + projection_pointers() + PROJECTION_END + after


def scoped_source(text=None):
    text = SCOPED_OUTPUT.read_text() if text is None else text
    before, remaining = text.split(SCOPED_START, 1)
    _, after = remaining.split(SCOPED_END, 1)
    return before + SCOPED_START + scoped_pointers() + SCOPED_END + after


def resource_source(text=None):
    text = RESOURCE_OUTPUT.read_text() if text is None else text
    before, remaining = text.split(RESOURCE_START, 1)
    _, after = remaining.split(RESOURCE_END, 1)
    return before + RESOURCE_START + resource_callbacks() + RESOURCE_END + after


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
    before, remaining = text.split(BINARY_START, 1)
    _, after = remaining.split(BINARY_END, 1)
    text = before + BINARY_START + pointer_factories("binary", ["A", "B"], "as_binary", owner="NativeBinary") + BINARY_END + after
    before, remaining = text.split(CAPTURE_START, 1)
    _, after = remaining.split(CAPTURE_END, 1)
    text = before + CAPTURE_START + capture_methods('binary') + CAPTURE_END + after
    before, remaining = text.split(BORROW_CAPTURE_START, 1)
    _, after = remaining.split(BORROW_CAPTURE_END, 1)
    text = before + BORROW_CAPTURE_START + capture_methods('borrow') + borrow_capture_pointers() + BORROW_CAPTURE_END + after
    return text.rstrip() + "\n"


if __name__ == "__main__":
    OUTPUT.write_text(source())
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    RESOURCE_OUTPUT.write_text(resource_source())
    print(f"wrote {RESOURCE_OUTPUT.relative_to(ROOT)}")
    PROJECTION_OUTPUT.write_text(projection_source())
    print(f"wrote {PROJECTION_OUTPUT.relative_to(ROOT)}")
    SCOPED_OUTPUT.write_text(scoped_source())
    print(f"wrote {SCOPED_OUTPUT.relative_to(ROOT)}")
