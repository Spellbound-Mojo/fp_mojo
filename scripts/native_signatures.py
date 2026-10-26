"""Native signature evidence shared by Context and Capture generators.

Admission fixes ownership and origin-bearing payloads before inferring a native
callback. Known consumed types use _NativeOwnedArg; read and result positions
need separate register bounds in Mojo 1.2. Invocation recovers those witnesses
only after comparing the complete native function type. No storage, effect
handling, or Result construction belongs here.
"""

from dataclasses import dataclass
from itertools import product

MD = "Movable & Deinitable"


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


def argument(type_, convention, *, thin=False, known=True):
    if convention == "r":
        return type_
    if convention == "m":
        return "mut " + type_
    return "var " + (f"_NativeOwnedArg[{type_}]" if thin and known else type_)


def variants(operands, result="R"):
    """Disjoint input/return ABI evidence; a known consumed type is projected."""
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
    for selected in product(*choices):
        payloads = tuple(x[0] for x in selected)
        params = sum((x[1] for x in selected), ())
        conditions = sum((x[2] for x in selected), ())
        for register_result in ((False, True) if result else (False,)):
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
):
    out = []
    for void in (True, False):
        for regs in product(
            *[((False, True) if m in ("r", "o") else (False,)) for m in shape]
        ):
            for rreg in ((False,) if void else (False, True)):
                conditions = []
                decl = []
                args = []
                passed = []
                for i, (mode, t, value, reg) in enumerate(
                    zip(shape, types, values, regs)
                ):
                    typ = t
                    if mode in ("r", "o"):
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
                            if reg
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
    )
    args = [argument(t, m) for t, m in zip(types, shape)]
    passed = [v + ("^" if m == "o" else "") for v, m in zip(values, shape)]
    if keyword:
        if args:
            args += ["/"]
        args += [f"var **kwargs: {keyword}"]
        passed += ["**" + keyword_value + "^"]
    cases = [
        (
            " raises Never",
            True,
            f"{result} == type_of(None) and {raising} and {error} == Never",
        ),
        (f" raises {error}", True, f"{result} == type_of(None) and {raising}"),
        ("", True, f"{result} == type_of(None) and not {raising}"),
        (" raises Never", False, f"{raising} and {error} == Never"),
        (f" raises {error}", False, raising),
        ("", False, "True"),
    ]
    for i, (effect, void, cond) in enumerate(cases):
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
