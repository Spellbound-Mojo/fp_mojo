"""Generate finite native capture signatures; execution stays in canonical callables.

Mojo argument conventions are part of a function type. Each argument bundle
therefore has one storage layout and invocation boundary per native shape.
The generator enumerates those shapes; it never generates Result handling.
"""

from itertools import product
import re
from native_signatures import (
    Operand,
    variants,
    argument,
    factory_pointer,
    native_dispatch,
    native_invocation,
)
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/fp/data/_capture.mojo"
ARGUMENT_OUTPUT = ROOT / "src/fp/callables/_arguments.mojo"
MD = "Movable & Deinitable"
MODES = {
    "r": ("borrow", "ImmOrigin"),
    "m": ("mutable", "MutOrigin"),
    "o": ("take", None),
}
SHAPES = [()] + [(x,) for x in MODES] + list(product(MODES, repeat=2))


def tag(shape, kw=False):
    return "".join(shape).upper() + ("K" if kw else "") or "Z"


def params(shape, kw=False, context=True):
    p = [f"{c}: {MD}" for c in "AB"[: len(shape)]]
    p += [f"{c.lower()}: {MODES[m][1]}" for c, m in zip("AB", shape) if m != "o"]
    if kw:
        p += [f"K: {MD}"]
    if context:
        p += [f"E: {MD}"]
    return p


def names(shape, kw=False, context=True, prefix=""):
    p = list("AB"[: len(shape)]) + [c.lower() for c, m in zip("AB", shape) if m != "o"]
    if kw:
        p += ["K"]
    if context:
        p += ["E"]
    return [prefix + x for x in p]


def typename(shape, kw=False, prefix="", error=None):
    ps = names(shape, kw, prefix=prefix)
    if error:
        ps[-1] = error
    return "_Args" + tag(shape, kw) + "[" + ", ".join(ps) + "]"


def storage_type(shape, kw=False, prefix=""):
    ps = names(shape, kw, False, prefix)
    return "_Arguments" + tag(shape, kw) + ("[" + ", ".join(ps) + "]" if ps else "")


def storage(shape, kw):
    ps = params(shape, kw, False)
    declaration = (
        "_Arguments" + tag(shape, kw) + ("[" + ", ".join(ps) + "]" if ps else "")
    )
    out = [f"@fieldwise_init\nstruct {declaration}(Movable):\n"]
    for name, typ in fields(shape, kw):
        for x in names(shape, kw, False):
            typ = re.sub(r"\b" + x + r"\b", "Self." + x, typ)
        out += [f"    var {name}: {typ}\n"]
    out += [transitions(shape, kw, stored=True)]
    return "".join(out)


def fields(shape, kw=False):
    out = []
    for c, m in zip("AB", shape):
        out.append(
            (c.lower() + "_value", c if m == "o" else f"Pointer[{c}, {c.lower()}]")
        )
    if kw:
        out.append(("options", "StringDict[K]"))
    return out


def sig(shape, kw=False, prefix=""):
    p = [argument(prefix + c, m) for c, m in zip("AB", shape)]
    if kw:
        if p:
            p += ["/"]
        p += [f"var **kwargs: {prefix}K"]
    return ", ".join(p)


def native(shape, kw):
    nm = tag(shape, kw)
    ps = params(shape, kw, False) + [
        f"R: {MD}",
        f"E: {MD}",
        f"F: {MD}",
        "raising: Bool",
    ]
    shape_type = storage_type(shape, kw)
    header = f'def _invoke_{nm}[{", ".join(ps)}](function: F, var arguments: {shape_type}) raises E -> R:\n'
    values = [
        "arguments." + c.lower() + "_value" + ("[]" if m != "o" else "")
        for c, m in zip("AB", shape)
    ]
    delegated = native_invocation(
        shape, list("AB"[: len(shape)]), values,
        keyword="K" if kw else None, keyword_value="arguments.options",
    )
    if delegated is not None:
        return header + "    return " + delegated + "\n\n"
    return (
        header
        + native_dispatch(
            shape,
            list("AB"[: len(shape)]),
            values,
            keyword="K" if kw else None,
            keyword_value="arguments.options",
        )
        + "\n"
    )


def transitions(shape, kw, *, stored):
    if kw:
        return ""
    out = []
    type_name = storage_type if stored else typename
    target = type_name(shape, True, "Self.").replace("Self.K", "K")
    if stored:
        values = [
            "self." + n + ("^" if not t.startswith("Pointer") else "")
            for n, t in fields(shape)
        ] + ["values^"]
        construct = f"{target}({', '.join(values)})"
    else:
        construct = f"{target}(self._arguments^.kwargs(**values^))"
    out += [
        f"    def kwargs[K: {MD}, //](deinit self, /, var **values: K) -> {target}:\n        return {construct}\n\n"
    ]
    if len(shape) < 2:
        c = "AB"[len(shape)]
        for m, (name, origin) in MODES.items():
            ps = (
                [f"{c}: {MD}"] + ([f"{c.lower()}: {origin}"] if origin else []) + ["//"]
            )
            target = (
                type_name(shape + (m,), False, "Self.")
                .replace("Self." + c, c)
                .replace("Self." + c.lower(), c.lower())
            )
            if stored:
                values = [
                    "self." + n + ("^" if not t.startswith("Pointer") else "")
                    for n, t in fields(shape)
                ]
                values += ["Pointer(to=value)" if origin else "value^"]
                construct = f"{target}({', '.join(values)})"
            else:
                construct = f"{target}(self._arguments^.{name}(value{'^' if not origin else ''}))"
            convention = "ref[" + c.lower() + "]" if origin else "var"
            out += [
                f"    def {name}[{', '.join(ps)}](deinit self, {convention} value: {c}) -> {target}:\n        return {construct}\n\n"
            ]
    return "".join(out)


def builder(shape, kw):
    out = [
        f'@fieldwise_init\nstruct _Args{tag(shape,kw)}[{", ".join(params(shape,kw))}](Movable):\n'
    ]
    stored = storage_type(shape, kw, "Self.")
    out += [f"    var _arguments: {stored}\n"]
    inputs, values = [], []
    for name, typ in fields(shape, kw):
        owned = not typ.startswith("Pointer")
        for x in names(shape, kw, False):
            typ = re.sub(r"\b" + x + r"\b", "Self." + x, typ)
        inputs += [("var " if owned else "") + name + ": " + typ]
        values += [name + ("^" if owned else "")]
    out += [
        f'    def __init__(out self{", " if inputs else ""}{", ".join(inputs)}):\n        self._arguments = {stored}({", ".join(values)})\n\n'
    ]
    out += [
        f"    def _run[R: {MD}, X: {MD}, F: {MD}, raising: Bool, q: ImmOrigin](deinit self, ref[q] function: F) -> Result[R, X]:\n"
    ]
    # The error belongs to invocation, not to argument storage.
    out += ["        var arguments = self._arguments^\n"]
    inv = (
        "_invoke_"
        + tag(shape, kw)
        + "["
        + ", ".join(names(shape, kw, False, "Self.") + ["R", "X", "F", "raising"])
        + "]"
    )
    out += [
        f"        return attempt_once(_BoundThunk[type_of(arguments), R, X, F, q, {inv}](arguments^, Pointer(to=function)))\n\n"
    ]
    for kind in (
        "pure",
        "raising",
        "pure_void",
        "raising_void",
        "never",
        "never_void",
    ):
        err = "Self.E" if kind in ("raising", "raising_void") else "Never"
        raised = kind not in ("pure", "pure_void")
        result = "type_of(None)" if kind.endswith("void") else "R"
        gen = ([f"R: {MD}"] if not kind.endswith("void") else []) + ["q: ImmOrigin"]
        effect = " raises " + err if raised else ""
        typ = f'def({sig(shape,kw,"Self.")}){effect}' + (
            "" if kind.endswith("void") else " -> R"
        )
        gen += ["//", f"F: {typ}"]
        arg = "ref[q] function: F"
        condition = " where Self.E != Never" if kind in ("never", "never_void") else ""
        bracket = "[" + ", ".join(gen) + "]" if gen else ""
        out += [
            f"    def run{bracket}(deinit self, {arg}) -> Result[{result}, {err}]{condition}:\n        return self^._run[{result}, {err}, type_of(function), {raised}](function)\n\n"
        ]
    # The literal Never specialization resolves the native read/read tie with
    # the selected-error closure signature. It retains the same ABI evidence
    # as inferred-error thin calls, including generic selected error contexts.
    operands = [
        Operand("Self." + c, m, read_parameter="P" if c == "A" else "Q")
        for c, m in zip("AB", shape)
    ]
    for native_kind in ("pure", "raising", "never"):
        raising = native_kind != "pure"
        for void in (False, True):
            for abi in variants(operands, None if void else "R"):
                gen = [name + ": " + bound for name, bound in abi.parameters]
                if native_kind == "raising":
                    gen += ["X: " + MD]
                err = "X" if native_kind == "raising" else "Never"
                result = "type_of(None)" if void else "R"
                args = [argument(t, m, thin=True) for t, m in zip(abi.payloads, shape)]
                if kw:
                    if args:
                        args += ["/"]
                    args += ["var **kwargs: Self.K"]
                typ = (
                    "def("
                    + ", ".join(args)
                    + ")"
                    + (" raises " + err if raising else "")
                    + " thin"
                    + ("" if void else " -> R")
                )
                conditions = list(abi.conditions) + (
                    ["_ErrorCompatible[Self.E, X]"] if native_kind == "raising" else []
                )
                condition = " where " + " and ".join(conditions) if conditions else ""
                bracket = "[" + ", ".join(gen + ["//"]) + "]" if gen else ""
                out += [
                    f"    def run{bracket}(deinit self, function: {typ}) -> Result[{result}, {err}]{condition}:\n        return self^._run[{result}, {err}, type_of(function), {raising}](function)\n\n"
                ]
    out += [transitions(shape, kw, stored=False)]
    return "".join(out)


header = '''"""Argument-first native capture admission, generated by scripts/generate_capture.py.

Select native errors and bind argument conventions before admitting a callback.
Borrowed slots retain their origins; consumed slots and keyword packs are owned.
Native run admission inlines to retain closure storage across generic forwards
at O0 on Mojo 1.2; callers need no annotation. Storage, consuming transitions
and invocation belong to callables._arguments. Its _invoke consumes the bundle,
so native cleanup handles a partially transferred value if the callback raises.
No allocation or type erasure is added.
"""
from std.collections import StringDict
from fp.callables.protocols import OnceThunk
from fp.callables._binding import _BoundThunk
from fp.callables.native import _NativeOwnedArg
from fp.data._result import Result
from fp.data._attempt import attempt_once
from fp._internal.errors import _ErrorCompatible

'''
argument_imports = [
    name
    for shape in SHAPES
    for kw in (False, True)
    for name in ("_Arguments" + tag(shape, kw), "_invoke_" + tag(shape, kw))
]
out = [
    header,
    "from fp.callables._arguments import " + ", ".join(argument_imports) + "\n\n",
]
argument_output = [
    '"""Consumed native argument storage and invocation, generated by generate_capture.py.\n\nNo error-selection metadata or Result dependency belongs to these bundles.\nCapture and legacy attempt share their ownership, origins and invocation.\n"""\nfrom std.builtin.rebind import rebind, rebind_var, downcast\nfrom std.collections import StringDict\nfrom .native import (_NativeOwnedArg, _call_native_binary, _call_native, _call_native_borrow, _call_native_thunk, _call_native_keywords, _NativeMutatingRef, _NativeMutOwnedRef, _NativeMutatingKeywordsRef, _NativeMutOwnedKeywordsRef)\n\n'
]
for shape in SHAPES:
    for kw in (False, True):
        declaration = native(shape, kw)
        invoke_header, body = declaration.split("\n", 1)
        body = body.replace("arguments.", "self.")
        for x in names(shape, kw, False):
            body = re.sub(r"\b" + x + r"\b", "Self." + x, body)
        method = f"    def _invoke[R: {MD}, E: {MD}, F: {MD}, raising: Bool](deinit self, function: F) raises E -> R:\n"
        method += "".join("    " + line + "\n" for line in body.splitlines())
        argument_output += [
            storage(shape, kw),
            method,
            invoke_header
            + "\n    return arguments^._invoke[R, E, F, raising](function)\n\n",
        ]
        out += [builder(shape, kw)]


def arguments_source():
    return (
        "\n".join(line.rstrip() for line in "".join(argument_output).splitlines()).rstrip()
        + "\n"
    )


out += ["struct Capture[E: Movable & Deinitable = Error]:\n"]
# Reuse zero-builder methods as static admission/factories.
b = builder((), False)
start = b.index("    def run[")
methods = b[start:]

methods = (
    methods.replace("deinit self, ", "")
    .replace("(deinit self, /, ", "(/, ")
    .replace("(deinit self)", "()")
)
methods = methods.replace("](/, var **values:", "](var **values:")
methods = methods.replace("return self^._run[", "return _ArgsZ[Self.E]()._run[")
methods = methods.replace("self._arguments^.", "_ArgumentsZ().")
for name in ("run", "kwargs", "borrow", "mutable", "take"):
    methods = re.sub(
        r"    def " + name + r"\b", r"    @staticmethod\n    def " + name, methods
    )
out += [methods]
out += ["""    @staticmethod
    def run[F: OnceThunk](var function: F) -> Result[F.Out, F.Error]:
        return attempt_once(function^)
"""]
# Stateful storage uses the same mutable/owned argument bundle. Its native
# factory is thin: users pass owned mutable state explicitly, not in captures.
state_class = """struct _Stateful[S: Movable & Deinitable, A: Movable & Deinitable,
                R: Movable & Deinitable, E: Movable & Deinitable,
                F: Movable & Deinitable, raising: Bool](Movable):
    var _state: Self.S
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F, var state: Self.S):
        self._function = Optional(function^)
        self._state = state^
    def state(ref self) -> ref[self._state] Self.S:
        return self._state
    def into_state(deinit self) -> Self.S:
        return self._state^
    def run(mut self, var value: Self.A) -> Result[Self.R, Self.E]:
        var arguments = _ArgsMO[Self.S, Self.A, origin_of(self._state), Self.E](Pointer(to=self._state), value^)
        return arguments^._run[Self.R, Self.E, Self.F, Self.raising](self._function.value())

"""
state_factory = ""
for raising in (False, True):
    for void in (False, True):
        operands = [Operand("S", "m"), Operand("A", "o", known=False)]
        for abi in variants(operands, None if void else "R"):
            gen = ["S: " + MD] + [name + ": " + bound for name, bound in abi.parameters]
            if raising:
                gen += ["X: " + MD]
            err = "X" if raising else "Never"
            result = "type_of(None)" if void else "R"
            args = [
                argument(t, op.convention, thin=True, known=op.known)
                for t, op in zip(abi.payloads, operands)
            ]
            typ = (
                "def("
                + ", ".join(args)
                + ")"
                + (" raises X" if raising else "")
                + " thin"
                + ("" if void else " -> R")
            )
            pointer = factory_pointer(abi)
            conditions = list(pointer.conditions) + (
                ["_ErrorCompatible[Self.E, X]"] if raising else []
            )
            condition = " where " + " and ".join(conditions) if conditions else ""
            gen += [name + ": " + bound for name, bound in pointer.parameters]
            target = f"_Stateful[S, A, {result}, {err}, type_of(function), {raising}]"
            state_factory += f'    @staticmethod\n    def stateful[{", ".join(gen+['//'])}]({pointer.argument}: {typ}, var state: S) -> {target}{condition}:\n        return {target}(function, state^)\n'
out += [state_factory]
out += [
    "    @staticmethod\n    def args() -> _ArgsZ[Self.E]:\n        return _ArgsZ[Self.E]()\n\n    @staticmethod\n    def args[A: Movable & Deinitable, //](var first: A) -> _ArgsO[A, Self.E]:\n        return _ArgsO[A, Self.E](first^)\n\n    @staticmethod\n    def args[A: Movable & Deinitable, B: Movable & Deinitable, //](var first: A, var second: B) -> _ArgsOO[A, B, Self.E]:\n        return _ArgsOO[A, B, Self.E](first^, second^)\n\n",
    state_class,
]
out.insert(1, "from fp.callables.products import _OptionalCell\n\n")


def source():
    text = document("".join(out)).replace(
        "    def run[", "    @always_inline\n    def run["
    )
    # A native callback must never infer the context's E. Mojo leaves metatype
    # defaults unbound during static overload selection, so direct run/stateful
    # admission requires an already constructed, zero-size context receiver.
    start = text.index("struct Capture[")
    end = text.index("\nstruct _Stateful[", start)
    root = text[start:end].replace(
        "struct Capture[E: Movable & Deinitable = Error]:",
        "@fieldwise_init\nstruct Capture[E: Movable & Deinitable = Error](ImplicitlyCopyable):",
    )
    root = re.sub(
        r"    @staticmethod\n((?:    @always_inline\n)?    def (?:run|stateful)[^\n]*)",
        r"\1",
        root,
    )
    lines = root.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.startswith(("    def run", "    def stateful")):
            pivot = line.index("](") + 2 if "](" in line else line.index("(") + 1
            lines[i] = line[:pivot] + "self, " + line[pivot:]
    return (
        "\n".join(
            line.rstrip()
            for line in (text[:start] + "".join(lines) + text[end:]).splitlines()
        )
        + "\n"
    )


def document(text):
    """Document every root overload; the private bundle contract is in the guide."""
    pos = text.index("struct Capture[")
    before, public = text[:pos], text[pos:]
    public = public.replace(
        "struct Capture[E: Movable & Deinitable = Error]:\n",
        'struct Capture[E: Movable & Deinitable = Error]:\n    """Select native errors, bind arguments, and capture one call as a Result.\n\n    `Capture[E].mutable(state).take(value^).run(callback)` fixes the error type,\n    argument types and ownership before callback inference. Use `borrow` for\n    shared access, `mutable` for exclusive access, and `take` for consumption.\n    Up to two positional operands can be followed by `kwargs`. `args` binds\n    zero, one or two consumed operands. The bundle is movable and runs once.\n    An unused bundle destroys its owned arguments without calling anything.\n\n    Construct `Capture[E]()` before direct `run` or `stateful` admission.\n    This fixes E before a native callback is matched. A reusable context such\n    as `var capture = Capture[E]()` also provides `capture.args(...)`,\n    `capture.borrow(...)`, `capture.mutable(...)`, `capture.take(...)` and\n    `capture.kwargs(...)`; it stores no arguments and is reusable after errors.\n\n    Pure functions produce `Result[R, Never]`; raising functions retain E.\n    No-value callbacks return `Result[None, E]`. Native callbacks are borrowed\n    for the call; OnceThunk owners are consumed and retain their own error.\n    Empty keyword packs require K or a typed dictionary. `stateful` owns an\n    explicit state value for repeated calls through a plain native function.\n    Existing `attempt` entry points remain available for compatibility.\n\n    Parameters:\n        E: The native callback error type, selected before inference; Error by default.\n    """\n',
    )
    descriptions = {
        "run": (
            "Call once and retain the exact native outcome.",
            "The callback output in Ok, or its declared error in Err.",
        ),
        "borrow": (
            "Bind a shared positional argument before selecting a callback.",
            "A consumed-once bundle borrowing the original value and origin.",
        ),
        "mutable": (
            "Bind an exclusive positional argument before selecting a callback.",
            "A consumed-once bundle retaining exclusive access to the original value.",
        ),
        "take": (
            "Move a positional argument into a pending call.",
            "A consumed-once bundle owning the argument.",
        ),
        "kwargs": (
            "Move a homogeneous native keyword pack into a pending call.",
            "A consumed-once bundle owning the keyword dictionary.",
        ),
        "args": (
            "Bind consumed positional arguments for a single call.",
            "A consumed-once argument bundle; append arguments or keywords before run.",
        ),
        "stateful": (
            "Own explicit state for repeated calls through a plain native function.",
            "A movable owner with run(value), state() and into_state() methods.",
        ),
    }
    parameter_docs = {
        "A": "The first argument type, including its origins.",
        "B": "The second argument type, including its origins.",
        "S": "The owned state type, including its origins.",
        "R": "The callback result type, inferred from the callback.",
        "X": "The inferred native callback error type.",
        "P": "The native register read type, equal to the bound argument.",
        "Q": "The second native register read type, equal to the bound argument.",
        "K": "The keyword value type, inferred from nonempty values or supplied explicitly.",
        "F": "The exact callback type, preserving its native signature and captures.",
        "a": "The first argument origin, inferred from the bound value.",
        "q": "The callback origin, inferred from the borrowed function.",
    }
    argument_docs = {
        "function": "The callback to invoke; borrowed for a native call or consumed for OnceThunk.",
        "state": "The explicit state, moved into the reusable owner.",
        "value": "The value to bind using this method’s ownership convention.",
        "first": "The first value, consumed.",
        "second": "The second value, consumed.",
        "values": "The homogeneous keyword values, consumed.",
    }

    def add(match):
        signature, name = match.group(0), match.group(1)
        summary, returns = descriptions[name]
        params = (
            signature.split("](", 1)[0].split("[", 1)[1]
            if "[" in signature.split("(", 1)[0]
            else ""
        )
        parameters = re.findall(r"(?:^|, )([A-Za-z]+):", params)
        # Parse argument names from the signature separately from native type parameters.
        names = [n for n in argument_docs if re.search(r"\b" + n + r":", signature)]
        docs = ['        """' + summary + "\n"]
        if parameters:
            docs += ["\n        Parameters:\n"] + [
                "            " + p + ": " + parameter_docs[p] + "\n" for p in parameters
            ]
        if names:
            docs += ["\n        Args:\n"] + [
                "            " + n + ": " + argument_docs[n] + "\n" for n in names
            ]
        docs += ["\n        Returns:\n            " + returns + '\n        """\n']
        return signature + "".join(docs)

    root, tail = public.split("struct _Stateful[", 1)
    root = re.sub(r"    def (\w+)[^\n]+:\n", add, root)
    return before + root + "struct _Stateful[" + tail


if __name__ == "__main__":
    OUTPUT.write_text(source())
    ARGUMENT_OUTPUT.write_text(arguments_source())
    print(f"wrote {OUTPUT.relative_to(ROOT)} and {ARGUMENT_OUTPUT.relative_to(ROOT)}")
