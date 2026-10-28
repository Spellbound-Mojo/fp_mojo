"""Native signature evidence and adapter names shared by syntax generators.

Admission fixes ownership and origin-bearing payloads before inferring a native
callback. Known consumed types use _NativeOwnedArg; read and result positions
need separate register bounds in Mojo 1.2. Invocation recovers those witnesses
only after comparing the complete native function type. No storage, effect
handling, or Result construction belongs here.
"""

from dataclasses import dataclass, replace
from itertools import product
import re

MD = "Movable & Deinitable"


@dataclass(frozen=True)
class CallbackShape:
    contract: str
    repeatable: str
    borrowed: str
    owned: str
    inputs: tuple[str, ...] = ("Arg",)
    result: str = "Out"
    error: str = "Error"


CALLBACK_SHAPES = {
    "owned": CallbackShape("UnaryContract", "Unary", "_NativeUnaryRef", "NativeUnary"),
    "borrow": CallbackShape(
        "BorrowCallContract", "BorrowCallable", "_NativeBorrowRef", "_NativeBorrow",
        ("Payload",), "Result", "Failure",
    ),
    "thunk": CallbackShape("ThunkContract", "Thunk", "_NativeThunkRef", "_NativeThunk", ()),
    "binary": CallbackShape(
        "BinaryContract", "Binary", "_NativeBinaryRef", "_NativeBinary", ("First", "Second")
    ),
    "nary": CallbackShape("UnaryContract", "Unary", "_NativeNary", "_OwnedNativeNary"),
}


@dataclass(frozen=True)
class CallableMetadata:
    """Associated types projected from an existing library callback."""

    inputs: tuple[str, ...]
    result: str
    error: str


def callable_metadata(mode, owner):
    """Use the shape's protocol members without choosing invocation policy."""
    shape = CALLBACK_SHAPES[mode]
    return CallableMetadata(
        tuple(owner + "." + field for field in shape.inputs),
        owner + "." + shape.result,
        owner + "." + shape.error,
    )


def callable_protocol(mode, *, repeatable=False):
    """The library protocol for a callback shape, before native admission."""
    shape = CALLBACK_SHAPES[mode]
    return shape.repeatable if repeatable else shape.contract


def native_adapter(mode, payloads, result, error, function, raising, *, origin=None):
    """Spell an existing owner or reference view without choosing admission.

    An origin selects a borrowed callback view; its absence selects ownership.
    Payload conventions, ABI evidence and caller parameter order stay with the
    signature generator. This only names existing adapters, never their storage
    or execution implementation.
    """
    shape = CALLBACK_SHAPES[mode]
    owner = shape.borrowed if origin is not None else shape.owned
    if mode == "nary":
        owner += str(len(payloads))
    parameters = [*payloads, result, error, function, str(raising)]
    if origin is not None:
        parameters.append(origin)
    return owner + "[" + ", ".join(parameters) + "]"


@dataclass
class Callback:
    """Ordered admission parameters and the existing invocation adapter.

    Emitters may specialize this description for their own surface. Renaming
    returns a separate description so two callback positions cannot share edits.
    """

    parameters: list[str]
    explicit: list[str]
    argument: str
    type: str
    build: str
    payload: str
    result: str
    error: str
    mode: str

    def renamed(self, mapping):
        """Substitute complete parameter identifiers, retaining their order."""
        pattern = re.compile(r"\b(" + "|".join(map(re.escape, mapping)) + r")\b")

        def change(value):
            return (
                pattern.sub(lambda match: mapping[match[0]], value)
                if mapping
                else value
            )

        fields = {
            name: change(getattr(self, name))
            for name in ("argument", "type", "build", "payload", "result", "error")
        }
        return replace(
            self,
            parameters=[change(value) for value in self.parameters],
            explicit=[change(value) for value in self.explicit],
            **fields,
        )


def callback(mode, kind, arg="function", second=False):
    """Describe callback admission without choosing operation semantics.

    Legacy native signatures retain their explicit parameter positions and
    callback borrows. Origin-indexed views are also shared by selected-context
    emitters, which retain their own admission policy.
    """
    f, p, r, x, o = (
        ("G", "Q", "S", "Y", "q")
        if second
        else ("C", "A" if mode == "owned" else "P", "R", "X", "o")
    )
    if kind == "view":
        if mode != "owned":
            raise ValueError("Shared unary views consume their explicit operand")
        view = f"{f}._View[{o}]"
        return Callback(
            [f"{f}: _UnaryViewable", f"{o}: ImmOrigin"], [],
            f"ref[{o}] {arg}: {f}", view, f"{arg}._unary_view()",
            view + ".Arg", view + ".Out", view + ".Error", mode,
        )
    if kind == "library":
        trait = callable_protocol(mode)
        metadata = callable_metadata(mode, f)
        return Callback(
            [f"{f}: {trait} & {MD}"],
            [],
            f"var {arg}: {f}",
            f,
            arg + "^",
            metadata.inputs[0] if metadata.inputs else "",
            metadata.result,
            metadata.error,
            mode,
        )
    params = (
        [] if mode == "thunk" else [f"{p}: " + ("AnyType" if mode == "borrow" else MD)]
    ) + [f"{r}: {MD}", f"{o}: ImmOrigin"]
    error = x if kind == "raising" else "Never"
    base = {"borrow": "Borrowing", "owned": "Unary", "thunk": "Thunk"}[mode]
    native_args = (f"{p}, " if mode != "thunk" else "") + r
    trait = (
        f"_Raising{base}[{native_args}, {x}]"
        if kind == "raising"
        else f"_{base}[{native_args}]"
    )
    explicit = ([f"{x}: {MD}"] if kind == "raising" else []) + [f"{f}: {trait}"]
    typ = native_adapter(
        mode, [p] if mode != "thunk" else [], r, error, f, kind == "raising", origin=o
    )
    return Callback(
        params,
        explicit,
        f"ref[{o}] {arg}: {f}",
        typ,
        f"{typ}(Pointer(to={arg}))",
        p,
        r,
        error,
        mode,
    )


@dataclass(frozen=True)
class NativeInvocation:
    """An existing invocation boundary and the operands it consumes or borrows."""

    shape: str
    types: tuple[str, ...]
    values: tuple[str, ...]
    owner: str
    keywords: bool = False
    view: bool = False


NATIVE_INVOCATIONS = {
    "thunk": NativeInvocation("", (), (), "_call_native_thunk"),
    "unary": NativeInvocation("o", ("A",), ("value",), "_call_native"),
    "borrow": NativeInvocation("r", ("P",), ("payload",), "_call_native_borrow"),
    "binary": NativeInvocation("oo", ("A", "B"), ("first", "second"), "_call_native_binary"),
    "keywords": NativeInvocation("", (), (), "_call_native_keywords", keywords=True),
    "mutating": NativeInvocation("m", ("A",), ("value",), "_NativeMutatingRef", view=True),
    "mut_owned": NativeInvocation("mo", ("A", "B"), ("first", "second"), "_NativeMutOwnedRef", view=True),
    "mutating_keywords": NativeInvocation("m", ("A",), ("first",), "_NativeMutatingKeywordsRef", keywords=True, view=True),
    "mut_owned_keywords": NativeInvocation("mo", ("A", "B"), ("first", "second"), "_NativeMutOwnedKeywordsRef", keywords=True, view=True),
}


def native_invocation(shape, payloads, values, *, keyword=None, keyword_value="values",
                      result="R", error="E", function_type="F", function="function",
                      raising="raising"):
    """Delegate a matching shape to its existing owner, or return None.

    Values are lvalues; consuming conventions and the owned keyword pack supply
    their move markers here. Missing mixed shapes retain native_dispatch in the
    argument bundle. This function describes calls, never their execution.
    """
    shape = "".join(shape)
    owner = next((item for item in NATIVE_INVOCATIONS.values()
                  if item.shape == shape and item.keywords == (keyword is not None)), None)
    if owner is None:
        return None
    assert len(payloads) == len(values) == len(shape)
    parameters = [*payloads, *([keyword] if keyword is not None else []),
                  result, error, function_type, raising]
    _, arguments = _call_arguments(shape, payloads, values, keyword, keyword_value)
    if owner.view:
        parameters.append(f"origin_of({function})")
        adapter = owner.owner + "[" + ", ".join(parameters) + "]"
        return f"{adapter}(Pointer(to={function})).invoke({', '.join(arguments)})"
    arguments.insert(0, function)
    return owner.owner + "[" + ", ".join(parameters) + "](" + ", ".join(arguments) + ")"


@dataclass(frozen=True)
class Operand:
    type: str
    convention: str
    known: bool = True
    read_parameter: str = ""


@dataclass(frozen=True)
class ThinABI:
    payloads: tuple
    parameters: tuple
    conditions: tuple


@dataclass(frozen=True)
class FactoryPointer:
    parameters: tuple
    conditions: tuple
    argument: str


def factory_pointer(abi, *, name="function", origin="q"):
    """Admit an owned thin pointer, including forwards with symbolic ABI.

    A generic forward cannot prove negative register conformance. Borrow its
    pointer at admission so exact by-value register variants take priority for
    concrete declarations. The factory copies the pointer into its existing
    owner; the temporary borrow never becomes part of the stored callback.
    This policy is for thin pointers, never captured closures.
    """
    fallback = all(bound == MD for _, bound in abi.parameters)
    return FactoryPointer(
        ((origin, "ImmOrigin"),) if fallback else (),
        () if fallback else abi.conditions,
        f"ref[{origin}] {name}" if fallback else name,
    )


def argument(type_, convention, *, thin=False, known=True):
    if convention == "r":
        return type_
    if convention == "m":
        return "mut " + type_
    return "var " + (f"_NativeOwnedArg[{type_}]" if thin and known else type_)


def variants(operands, result="R", *, result_register=None):
    """Disjoint ABI evidence, retaining inferred parameter positions.

    An operation may fix the result ABI without fixing its inferred parameter:
    a Bool predicate cannot satisfy the non-register result alternative. The
    operation still owns result equality and every input convention remains.
    """
    choices = []
    for op in operands:
        if op.convention == "r":
            if not op.known:
                raise ValueError("Unbound read types need a declared owner")
            p = op.read_parameter
            if not p:
                raise ValueError("Read operands need a fresh inference parameter")
            choices.append(
                (
                    (
                        op.type,
                        (),
                        (f"not conforms_to({op.type}, TrivialRegisterPassable)",),
                    ),
                    (p, ((p, "TrivialRegisterPassable"),), (f"{p} == {op.type}",)),
                )
            )
        elif op.convention == "o" and not op.known:
            choices.append(
                (
                    (
                        op.type,
                        ((op.type, MD),),
                        (f"not conforms_to({op.type}, RegisterPassable)",),
                    ),
                    (op.type, ((op.type, "RegisterPassable & Deinitable"),), ()),
                )
            )
        else:
            choices.append(((op.type, (), ()),))
    result_choices = (False, True) if result_register is None else (result_register,)
    if not result:
        result_choices = (False,)
    for selected in product(*choices):
        payloads = tuple(x[0] for x in selected)
        params = sum((x[1] for x in selected), ())
        conditions = sum((x[2] for x in selected), ())
        for register_result in result_choices:
            bound = "RegisterPassable & Deinitable" if register_result else MD
            yield ThinABI(
                payloads,
                params + (((result, bound),) if result else ()),
                conditions
                + (
                    (f"not conforms_to({result}, RegisterPassable)",)
                    if result and not register_result
                    else ()
                ),
            )


# Dispatch is separate from admission: the complete native F is already known.
# Concrete ABI witnesses must be introduced in comptime branches before forming
# its function type, including register results and borrowed register operands.


def _effect_cases(result, error, raising):
    """Literal no-value and Never signatures are shared by every invocation."""
    return (
        (
            " raises Never",
            True,
            f"{result} == type_of(None) and {raising} and {error} == Never",
        ),
        (f" raises {error}", True, f"{result} == type_of(None) and {raising}"),
        ("", True, f"{result} == type_of(None) and not {raising}"),
        (" raises Never", False, f"{raising} and {error} == Never"),
        (f" raises {error}", False, raising),
        ("", False, f"not {raising}"),
    )


def _call_arguments(shape, types, values, keyword, keyword_value, *, known_owned=False):
    args = [argument(t, m, thin=known_owned) for t, m in zip(types, shape)]
    passed = [
        (
            f"rebind_var[_NativeOwnedArg[{t}]]({v}^)"
            if known_owned and m == "o"
            else v + ("^" if m == "o" else "")
        )
        for t, v, m in zip(types, values, shape)
    ]
    if keyword:
        if args:
            args += ["/"]
        args += [f"var **kwargs: {keyword}"]
        passed += ["**" + keyword_value + "^"]
    return args, passed


def thin_dispatch(
    shape,
    types,
    values,
    *,
    keyword=None,
    keyword_value="values",
    result="Self.R",
    error="Self.E",
    function_type="Self.F",
    function="self.function[]",
    raising="Self.raising",
    indent="        ",
    known_owned=False,
):
    """Recover concrete thin ABIs, then accept an exact symbolic signature.

    N-ary invocation already knows every consumed input. Project those inputs
    instead of enumerating 2**arity register combinations. Result and read
    positions still require explicit register evidence.
    """
    out = []
    for void in (True, False):
        for regs in product(
            *[
                (
                    (False, True)
                    if m == "r" or (m == "o" and not known_owned)
                    else (False,)
                )
                for m in shape
            ]
        ):
            for rreg in ((False,) if void else (False, True)):
                # The exact symbolic signature below also covers the all-memory
                # case, without requiring negative register evidence.
                if not any(regs) and not rreg:
                    continue
                conditions = []
                decl = []
                args = []
                passed = []
                for i, (mode, t, value, reg) in enumerate(
                    zip(shape, types, values, regs)
                ):
                    typ = t
                    projected = mode == "o" and known_owned
                    if projected:
                        typ = f"_NativeOwnedArg[{t}]"
                    elif mode in ("r", "o"):
                        trait = (
                            "TrivialRegisterPassable"
                            if mode == "r"
                            else "RegisterPassable & Deinitable"
                        )
                        condition = f"conforms_to({t}, {trait})"
                        conditions.append(condition if reg else "not " + condition)
                        if reg:
                            typ = f"Arg{i}"
                            decl.append(f"comptime {typ} = downcast[{t}, {trait}]")
                    args.append(
                        ("" if mode == "r" else "mut " if mode == "m" else "var ") + typ
                    )
                    passed.append(
                        f"rebind[{typ}]({value})"
                        if reg and mode == "r"
                        else (
                            f"rebind_var[{typ}]({value}^)"
                            if reg or projected
                            else value + ("^" if mode == "o" else "")
                        )
                    )
                output = result
                if void:
                    conditions.append(f"{result} == type_of(None)")
                else:
                    condition = f"conforms_to({result}, RegisterPassable)"
                    conditions.append(condition if rreg else "not " + condition)
                    if rreg:
                        output = "Out"
                        decl.append(
                            f"comptime Out = downcast[{result}, RegisterPassable & Deinitable]"
                        )
                if keyword:
                    if args:
                        args += ["/"]
                    args += [f"var **kwargs: {keyword}"]
                    passed += ["**" + keyword_value + "^"]
                out += [indent + "comptime if " + " and ".join(conditions) + ":\n"]
                out += [indent + "    " + line + "\n" for line in decl]
                for i, (effect, guard) in enumerate(
                    [
                        (f" raises Never", f"{raising} and {error} == Never"),
                        (f" raises {error}", raising),
                        ("", f"not {raising}"),
                    ]
                ):
                    typ = (
                        "def("
                        + ", ".join(args)
                        + ")"
                        + effect
                        + " thin"
                        + ("" if void else " -> " + output)
                    )
                    out += [
                        indent
                        + f'    {"comptime if" if i==0 else "elif"} {guard} and {function_type} == {typ}:\n'
                    ]
                    if i == 2:
                        out += [indent + f"        comptime assert {error} == Never\n"]
                    call = f"rebind[{typ}]({function})(" + ", ".join(passed) + ")"
                    if void:
                        out += [
                            indent
                            + f"        _ = {call}\n"
                            + indent
                            + f"        return rebind_var[{result}](None)\n"
                        ]
                    else:
                        out += [
                            indent + f"        return rebind_var[{result}]({call})\n"
                        ]
    # A generic forward may not prove either concrete register condition.
    # Its original F still proves an exact generic thin signature. Check that
    # evidence before attempting closure conformance (thin pointers have none).
    args, passed = _call_arguments(
        shape, types, values, keyword, keyword_value, known_owned=known_owned
    )
    for effect, void, condition in _effect_cases(result, error, raising):
        typ = (
            "def("
            + ", ".join(args)
            + ")"
            + effect
            + " thin"
            + ("" if void else " -> " + result)
        )
        out += [indent + f"comptime if {condition} and {function_type} == {typ}:\n"]
        if not effect:
            out += [indent + f"    comptime assert {error} == Never\n"]
        call = f"rebind[{typ}]({function})(" + ", ".join(passed) + ")"
        if void:
            out += [
                indent + f"    _ = {call}\n",
                indent + f"    return rebind_var[{result}](None)\n",
            ]
        else:
            out += [indent + f"    return {call}\n"]
    return "".join(out)


def native_dispatch(
    shape,
    types,
    values,
    *,
    keyword=None,
    keyword_value="values",
    result="R",
    error="E",
    function_type="F",
    function="function",
    raising="raising",
    indent="    ",
    known_owned=False,
):
    out = thin_dispatch(
        shape,
        types,
        values,
        keyword=keyword,
        keyword_value=keyword_value,
        result=result,
        error=error,
        function_type=function_type,
        function=function,
        raising=raising,
        indent=indent,
        known_owned=known_owned,
    )
    args, passed = _call_arguments(shape, types, values, keyword, keyword_value)
    cases = _effect_cases(result, error, raising)
    for i, (effect, void, cond) in enumerate(cases):
        # The prior raising branches exhaust that effect; an unconditional
        # final branch is needed for generic return-path checking on Mojo 1.2.
        if i == len(cases) - 1:
            cond = "True"
        typ = (
            "def(" + ", ".join(args) + ")" + effect + ("" if void else " -> " + result)
        )
        out += indent + f'{"comptime if" if i==0 else "elif"} {cond}:\n'
        if not effect:
            out += indent + f"    comptime assert {error} == Never\n"
        out += indent + f"    comptime Fn = downcast[{function_type}, {typ}]\n"
        call = f"rebind[Fn]({function})(" + ", ".join(passed) + ")"
        if void:
            out += (
                indent
                + f"    _ = {call}\n"
                + indent
                + f"    return rebind_var[{result}](None)\n"
            )
        else:
            out += indent + f"    return {call}\n"
    return out
