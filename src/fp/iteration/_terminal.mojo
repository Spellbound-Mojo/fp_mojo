"""One consuming terminal driver and native step/result adaptations.

Typed callback pointers preserve native owner origins and captured writes through
ControlFlow at O3. The final native callable bridge keeps its read convention:
changing that bridge to ref corrupts some captured-callable arguments at O0.
Existing state/error/origin clients cover both boundaries.
"""

from std.iter import Iterator
from fp.data.control import Break, Continue, ControlFlow
from fp.iteration._advance import _next_optional


def _drive[A: Movable & Deinitable, B: Movable & Deinitable,
           T: Movable & Deinitable, I: Iterator, E: AnyType, C: AnyType,
           apply: def(var A, var T, C) raises E capturing -> ControlFlow[B, A]](
    context: C, var initial: A, var iterator: I
) raises E -> ControlFlow[B, A]:
    """Stop once on exhaustion, Break or failure, with native owned cleanup."""
    while True:
        var item = _next_optional[T, I](iterator)
        if not item:
            return ControlFlow[B, A](Continue(initial^))
        var value = item.take()
        # Callback failures cannot enter the source-exhaustion boundary.
        var control = apply(initial^, value^, context)
        if control.isa[Break[B]]():
            return control^
        initial = control^.unwrap[Continue[A]]().into_payload()


def _control_step[A: Movable & Deinitable, B: Movable & Deinitable,
                  T: Movable & Deinitable, E: AnyType, F: AnyType, origin: ImmOrigin,
                  apply: def(var A, var T, F) raises E capturing -> ControlFlow[B, A]](
    var accumulator: A, var value: T, function: Pointer[F, origin=origin]
) raises E capturing -> ControlFlow[B, A]:
    return apply(accumulator^, value^, function[])


def _fold_until[A: Movable & Deinitable, B: Movable & Deinitable,
                T: Movable & Deinitable, I: Iterator, E: AnyType, F: AnyType,
                apply: def(var A, var T, F) raises E capturing -> ControlFlow[B, A]](
    step: F, var initial: A, var iterator: I
) raises E -> ControlFlow[B, A]:
    return _drive[A, B, T, I, E, Pointer[F, origin=origin_of(step)],
        _control_step[A, B, T, E, F, origin_of(step), apply]](
        Pointer(to=step), initial^, iterator^)


def _continue_step[A: Movable & Deinitable, T: Movable & Deinitable,
                   E: AnyType, F: AnyType, origin: ImmOrigin,
                   apply: def(var A, var T, F) raises E capturing -> A](
    var accumulator: A, var value: T, function: Pointer[F, origin=origin]
) raises E capturing -> ControlFlow[Never, A]:
    return ControlFlow[Never, A](Continue(apply(accumulator^, value^, function[])))


def _fold_left[A: Movable & Deinitable, T: Movable & Deinitable,
               I: Iterator, E: AnyType, F: AnyType,
               apply: def(var A, var T, F) raises E capturing -> A](
    step: F, var initial: A, var iterator: I
) raises E -> A:
    var result = _drive[A, Never, T, I, E, Pointer[F, origin=origin_of(step)],
        _continue_step[A, T, E, F, origin_of(step), apply]](
        Pointer(to=step), initial^, iterator^)
    return result^.unwrap[Continue[A]]().into_payload()


def _reduce_optional[T: Movable & Deinitable, I: Iterator, E: AnyType,
                     F: AnyType,
                     apply: def(var T, var T, F) raises E capturing -> T](
    step: F, var iterator: I
) raises E -> Optional[T]:
    var first = _next_optional[T, I](iterator)
    if not first:
        return None
    var initial = first.take()
    return Optional(_fold_left[T, T, I, E, F, apply](step, initial^, iterator^))


def _find_step[T: Movable & Deinitable, E: AnyType, F: AnyType, origin: ImmOrigin,
               apply: def(T, F) raises E capturing -> Bool](
    var state: Tuple[], var value: T, predicate: Pointer[F, origin=origin]
) raises E capturing -> ControlFlow[T, Tuple[]]:
    if apply(value, predicate[]):
        return ControlFlow[T, Tuple[]](Break(value^))
    return ControlFlow[T, Tuple[]](Continue(state^))


def _find[T: Movable & Deinitable, I: Iterator, E: AnyType,
          F: AnyType, apply: def(T, F) raises E capturing -> Bool](
    predicate: F, var source: I
) raises E -> Optional[T]:
    var result = _drive[Tuple[], T, T, I, E, Pointer[F, origin=origin_of(predicate)],
        _find_step[T, E, F, origin_of(predicate), apply]](
        Pointer(to=predicate), Tuple(), source^)
    if result.isa[Break[T]]():
        return Optional(result^.unwrap[Break[T]]().into_payload())
    return None


def _quantify_step[T: Movable & Deinitable, E: AnyType, F: AnyType, origin: ImmOrigin,
                   apply: def(T, F) raises E capturing -> Bool](
    var stop_value: Bool, var value: T, predicate: Pointer[F, origin=origin]
) raises E capturing -> ControlFlow[Bool, Bool]:
    if apply(value, predicate[]) == stop_value:
        return ControlFlow[Bool, Bool](Break(stop_value))
    return ControlFlow[Bool, Bool](Continue(stop_value))


def _quantify[T: Movable & Deinitable, I: Iterator, E: AnyType,
              F: AnyType, apply: def(T, F) raises E capturing -> Bool](
    predicate: F, var source: I, stop_value: Bool
) raises E -> Bool:
    var result = _drive[Bool, Bool, T, I, E, Pointer[F, origin=origin_of(predicate)],
        _quantify_step[T, E, F, origin_of(predicate), apply]](
        Pointer(to=predicate), stop_value, source^)
    if result.isa[Break[Bool]]():
        return result^.unwrap[Break[Bool]]().into_payload()
    return not result^.unwrap[Continue[Bool]]().into_payload()


def _append[T: Movable & Deinitable](
    var values: List[T], var value: T, context: Tuple[]
) capturing -> List[T]:
    values.append(value^)
    return values^


def _collect_list[T: Movable & Deinitable, I: Iterator](var source: I) -> List[T]:
    return _fold_left[List[T], T, I, Never, Tuple[], _append[T]](
        Tuple(), List[T](), source^)
