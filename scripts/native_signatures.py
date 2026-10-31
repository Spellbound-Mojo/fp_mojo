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


def split_explicit(parameters):
    """Split explicit callback parameters around a defaulted family.

    Mojo rejects a required positional parameter after a defaulted one. A
    native callback's type and error follow the family, each defaulting to its
    own bound (an error to Never); inference from the argument still selects
    the actual types, and generic code can still bind `F=` or `E=`, so a
    rejected native signature still reports the conversion. A library callable
    bounded by a trait has no such default and is inferred before the marker.
    Returns (inferred, trailing).
    """
    inferred, trailing = [], []
    for parameter in parameters:
        name, bound = parameter.split(': ', 1)
        if bound.startswith(('def(', '_')):
            trailing.append(f'{name}: {bound} = {bound}')
        elif bound == MD:
            trailing.append(f'{name}: {bound} = Never')
        else:
            inferred.append(parameter)
    return inferred, trailing


def defaulted(parameters):
    """The trailing defaults of native callback parameters (see split_explicit)."""
    inferred, trailing = split_explicit(parameters)
    assert not inferred, f'library parameters cannot follow a defaulted family: {inferred}'
    return trailing


def source_default(trait, value="V"):
    """The default capability family of a source value (see _SourceFamily).

    An unrecognized value, or a family without the capability, yields
    _UnrecognizedCarrier, whose cast satisfies no family admission, so the call
    is rejected; an explicit family still binds.
    """
    family = f"_SourceFamily[{value}]"
    return f"downcast[{family} if conforms_to({family}, {trait}) else _UnrecognizedCarrier, {trait}]"


def callable_protocol(mode, *, repeatable=False):
    """The library protocol for a callback shape, before native admission."""
    shape = CALLBACK_SHAPES[mode]
    return shape.repeatable if repeatable else shape.contract


def native_adapter(mode, payloads, result, error, function, raising, *, origin=None, owner=None):
    """Spell an existing owner or reference view without choosing admission.

    An origin selects a borrowed callback view; its absence selects ownership.
    Payload conventions, ABI evidence and caller parameter order stay with the
    signature generator. This only names existing adapters, never their storage
    or execution implementation.
    An explicit owner preserves a public spelling while legacy consumers keep
    an existing alias of that same owner.
    """
    shape = CALLBACK_SHAPES[mode]
    owner = owner or (shape.borrowed if origin is not None else shape.owned)
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
        if mode in ("binary", "thunk"):
            trait = "_BinaryViewable" if mode == "binary" else "Thunk"
            owner = "_SharedBinaryRef" if mode == "binary" else "_SharedThunkRef"
            view = f"{owner}[{f}, {o}]"
            build = f"{view}(Pointer(to={arg}))"
        elif mode in ("owned", "borrow"):
            trait, alias, method = (("_UnaryViewable", "_View", "_unary_view") if mode == "owned"
                                    else ("_BorrowViewable", "_BorrowView", "_borrow_view"))
            view = f"{f}.{alias}[{o}]"
            build = f"{arg}.{method}()"
        else:
            raise ValueError("No shared callback view for " + mode)
        metadata = callable_metadata(mode, view)
        return Callback(
            [f"{f}: {trait}", f"{o}: ImmOrigin"], [],
            f"ref[{o}] {arg}: {f}", view, build,
            metadata.inputs[0] if metadata.inputs else "", metadata.result, metadata.error, mode,
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
    # Closures: the catalog's form, under this description's names.
    form = closure(mode, kind == "raising", arg=arg,
                   names={"C": f, "R": r, "X": x, "o": o, "in0": p})
    return Callback(
        list(form.parameters),
        list(form.explicit),
        form.argument,
        form.type,
        form.build,
        form.inputs[0] if form.inputs else p,
        form.result,
        form.error,
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
    fallback = all(bound in (MD, "AnyType") for _, bound in abi.parameters)
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
                # A borrowing factory can infer its input from the pointer.
                # Memory reads need no Movable/Deinitable payload witness.
                choices.append((
                    (op.type, ((op.type, "AnyType"),),
                     (f"not conforms_to({op.type}, TrivialRegisterPassable)",)),
                    (op.type, ((op.type, "TrivialRegisterPassable"),), ()),
                ))
                continue
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


@dataclass(frozen=True)
class NativeFactory:
    """Native pointer shape, ABI evidence and optional factory admission borrow."""
    parameters: tuple
    pointer: FactoryPointer
    signature: str
    adapter: str
    abi: ThinABI

    @property
    def argument(self):
        return self.pointer.argument + ": " + self.signature


def native_factories(mode, payloads, *, name="function", result="R", error="E", owner=None, origin="q", include_void=True):
    """Spell native factory signatures with shared ABI and no-value evidence.

    Consumers place their own parameters around the native parameters and the
    fallback pointer origin. The pointer is copied into an existing owner;
    its admission borrow never becomes a stored callback origin. Independent
    callback positions supply distinct origin names. Operand descriptors retain
    inputs already selected by a capability; plain names infer fresh inputs.
    """
    if mode not in ("thunk", "owned", "binary", "borrow"):
        raise ValueError("Unsupported native factory shape")
    if len(payloads) != len(CALLBACK_SHAPES[mode].inputs):
        raise ValueError("Native factory shape and operands must agree")
    convention = "r" if mode == "borrow" else "o"
    operands = [p if isinstance(p, Operand) else Operand(p, convention, known=False)
                for p in payloads]
    if any(op.convention != convention for op in operands):
        raise ValueError("Factory operands must match their callback convention")
    for raising in (False, True):
        for void in ((False, True) if include_void else (False,)):
            for abi in variants(operands, None if void else result):
                pointer = factory_pointer(abi, name=name, origin=origin)
                if void and mode != "borrow" and not pointer.parameters:
                    continue
                if void and mode != "borrow":
                    # A literal no-return signature fixes the result ABI. Its
                    # symbolic-input fallback must compete by value as well:
                    # borrowing it lets a typed-result alternative win before
                    # Mojo can prove that alternative's input ABI constraint.
                    # The exact no-return signature also admits register inputs;
                    # additional register alternatives would be ambiguous.
                    pointer = FactoryPointer((), (), name)
                # Read-only void inputs retain their register/memory evidence;
                # the ordinary borrowed fallback still admits symbolic inputs.
                parameters = abi.parameters + (((error, MD),) if raising else ())
                signature = ("def(" + ", ".join(argument(p, op.convention, thin=True, known=op.known) for p, op in zip(abi.payloads, operands)) + ")"
                             + (" raises " + error if raising else "") + " thin"
                             + ("" if void else " -> " + result))
                output = "type_of(None)" if void else result
                failure = error if raising else "Never"
                adapter = native_adapter(mode, list(abi.payloads), output, failure, f"type_of({name})", raising, owner=owner)
                yield NativeFactory(parameters, pointer, signature, adapter, abi)



@dataclass(frozen=True)
class Admission:
    """One callback form an entry point declares, and the value it passes on.

    `parameters` are inferred and precede the operation's `//`; `explicit`
    follow the operation's own parameters. `conditions` join the operation's
    where clause. `type` is the library value the operation receives, and
    `build` produces it from the argument.
    """

    kind: str
    raising: bool
    parameters: tuple
    explicit: tuple
    argument: str
    type: str
    build: str
    inputs: tuple
    result: str
    error: str
    conditions: tuple


_CONVENTIONS = {"owned": "o", "borrow": "r", "binary": "o", "thunk": ""}
_NATIVE = {"owned": "Unary", "borrow": "Borrowing", "binary": "Binary", "thunk": "Thunk"}


def admissions(mode, elements=(), *, arg="function", fixed_error=None, known_closure=False,
               library=True, view=True, plain=True, repeatable=False, names=None, result_register=None):
    """Every form an entry point declares for one callback, and nothing else.

    `elements` are the callback's operand types, already known from earlier
    arguments or from `Self`; value-first free functions and every fluent
    surface know them. Forms, each required on Mojo 1.2:

    - library callable and shared view; the operation's contract checks
      their inputs;
    - closures, pure and raising. Their inputs are inferred and related to the
      elements in `where`: spelling a closure input with a value-dependent
      element crashes the compiler on a mismatched callback. A surface whose
      elements are fixed by `Self` may spell them directly (`known_closure`).
      With `fixed_error` (a surface's selected error) the raising closures are
      `raises <fixed_error>` and `raises Never`, because inferring a closure
      error crashes on wrong arity, convention or `mut`;
    - plain functions, pure with memory and register results (stored
      register-result pointers need the split) and raising with one result
      bound. Borrowed register payloads carry their own evidence.

    An element of None leaves that input fresh and unrelated: the surface
    relates it itself (a carrier-specific method compares `Self.Value` with the
    carrier spelled over it), and plain functions, which need the element, are
    not offered.

    `names` renames C (the closure type), L (the library type, default C), R,
    X, o and the fresh inputs in0, in1, so a surface keeps its public
    parameter names. `result_register` fixes the plain-function result
    bound when the operation fixes the result (a `Bool` predicate).
    """
    names = {"C": "C", "R": "R", "X": "X", "o": "o", **(names or {})}
    C, R, X, o = names["C"], names["R"], names["X"], names["o"]
    convention = _CONVENTIONS[mode]
    elements = tuple(elements)
    if len(elements) != len(CALLBACK_SHAPES[mode].inputs):
        raise ValueError("Callback shape and elements must agree")
    fresh = tuple(names.get(f"in{i}", f"{C}{i}") for i in range(len(elements)))
    out = []
    if library:
        L = names.get("L", C)
        trait = callable_protocol(mode, repeatable=repeatable)
        metadata = callable_metadata(mode, L)
        out.append(Admission(
            "library", False, (), (f"{L}: {trait}" + ("" if repeatable else f" & {MD}"),), f"var {arg}: {L}",
            L, arg + "^", metadata.inputs, metadata.result, metadata.error, ()))
    if view and mode in ("owned", "borrow", "binary"):
        shared = callback(mode, "view", arg=arg).renamed({"C": C, "o": o})
        out.append(Admission(
            "view", False, tuple(shared.parameters), (), shared.argument, shared.type, shared.build,
            (shared.payload,) if shared.payload else (), shared.result, shared.error, ()))
    # Closures, borrowed in place.
    inputs = elements if known_closure else fresh
    relations = () if known_closure else tuple(f"{e} == {i}" for e, i in zip(elements, inputs) if e is not None)
    input_params = () if known_closure else tuple(
        (f"{i}: AnyType" if convention == "r" else f"{i}: {MD}") for i in inputs)
    spelled = ", ".join((i if convention == "r" else "var " + i) for i in inputs)
    efforts = ([("Never", False, ""), (fixed_error, True, ""), ("Never", True, f"{fixed_error} != Never")]
               if fixed_error else [("Never", False, ""), (X, True, "")])
    for error, raising, guard in efforts:
        signature = f"def({spelled})" + (f" raises {error}" if raising else "") + f" -> {R}"
        adapter = native_adapter(mode, list(inputs), R, error, C, raising, origin=o)
        explicit = ((f"{X}: {MD}",) if raising and error == X else ()) + (f"{C}: {signature}",)
        out.append(Admission(
            "closure", raising, (*input_params, f"{R}: {MD}", f"{o}: ImmOrigin"), explicit,
            f"ref[{o}] {arg}: {C}", adapter, f"{adapter}(Pointer(to={arg}))", tuple(inputs), R, error,
            relations + ((guard,) if guard else ())))
    # Plain functions, copied into an owned callable.
    if not plain or any(e is None for e in elements):
        return out
    operands = [Operand(e, convention, read_parameter=names.get(f"read{i}", f"{C}P{i}"))
                for i, e in enumerate(elements)]
    for raising in (False, True):
        bound = result_register if result_register is not None else (False if raising else None)
        for abi in variants(operands, R, result_register=bound):
            error = X if raising else "Never"
            signature = ("def(" + ", ".join(argument(p, op.convention, thin=True) for p, op in zip(abi.payloads, operands))
                         + ")" + (f" raises {X}" if raising else "") + f" thin -> {R}")
            adapter = native_adapter(mode, list(abi.payloads), R, error, f"type_of({arg})", raising)
            conditions = tuple(c for c in abi.conditions if not (raising and c == f"not conforms_to({R}, RegisterPassable)"))
            if raising and fixed_error:
                conditions += (f"_ErrorCompatible[{fixed_error}, {X}]",)
            out.append(Admission(
                "thin", raising, tuple(f"{p}: {b}" for p, b in abi.parameters) + ((f"{X}: {MD}",) if raising else ()), (),
                f"{arg}: {signature}", adapter, f"{adapter}({arg})", tuple(abi.payloads), R, error, conditions))
    return out

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


def closure(mode, raising, *, elements=None, names=None, arg="function", fixed_error=None, never=False):
    """One borrowed closure form from the catalog, for a surface's own layout.

    `elements` defaults to fresh inputs the surface relates itself. With
    `fixed_error`, `raising` selects `raises <fixed_error>` and `never` the
    explicit `raises Never` form.
    """
    elements = [None] * len(CALLBACK_SHAPES[mode].inputs) if elements is None else elements
    forms = [f for f in admissions(mode, elements, arg=arg, fixed_error=fixed_error, library=False,
                                   view=False, plain=False, names=names) if f.kind == "closure"]
    if fixed_error:
        return forms[2] if never else forms[1] if raising else forms[0]
    return forms[1] if raising else forms[0]

