"""Native loop scheduling, shared by the functional control-flow facades."""
from fp._internal.errors import _ErrorCompatible, _propagate_error


def _while[A: Movable & Deinitable, P: AnyType, F: AnyType,
           PE: Movable & Deinitable, BE: Movable & Deinitable,
           test: def(A, P) raises PE capturing -> Bool,
           step: def(F, var A) raises BE capturing -> A,
           E: Movable & Deinitable](predicate: P, body: F, var value: A
) raises E -> A where _ErrorCompatible[E, PE] and _ErrorCompatible[E, BE]:
    # As in iteration._terminal, retain native pointers to receiver storage.
    # The last application boundary keeps its native read convention.
    var p = Pointer(to=predicate)
    var f = Pointer(to=body)
    while True:
        var again: Bool
        try:
            again = test(value, p[])
        except error:
            _propagate_error[E](error^)
        if not again:
            return value^
        try:
            value = step(f[], value^)
        except error:
            _propagate_error[E](error^)


def _indexed[A: Movable & Deinitable, C: AnyType, E: Movable & Deinitable,
             step: def(var A, Int, C) raises E capturing -> A,
             unroll: Int, static: Bool = False, lower_bound: Int = 0,
             upper_bound: Int = 0](lower: Int, upper: Int, context: C, var value: A
) raises E -> A:
    comptime assert unroll >= 0, "control: unroll must be nonnegative"
    comptime assert unroll != 0 or static, "control: full unrolling requires static bounds or static_length"
    comptime if unroll == 0:
        comptime for index in range(lower_bound, upper_bound):
            value = step(value^, index, context)
    else:
        var index = lower
        while index < upper:
            comptime for offset in range(unroll):
                if index < upper:
                    value = step(value^, index, context)
                    # index < upper <= Int.MAX proves this increment is safe.
                    index += 1
    return value^


def _for_step[A: Movable & Deinitable, F: AnyType, E: Movable & Deinitable,
              origin: ImmOrigin,
              apply: def(var Int, var A, F) raises E capturing -> A](
    var value: A, index: Int, function: Pointer[F, origin]
) raises E capturing -> A:
    return apply(index, value^, function[])
