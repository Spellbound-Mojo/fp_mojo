"""Derived terminal rules over the canonical accumulation driver."""
from fp.functions.composition import Identity as _Same
from fp.callables.native import _Unary, _RaisingUnary, _NativeUnaryRef, _Borrowing, _RaisingBorrowing, _NativeBorrowRef
from ._advance import _Source

from std.builtin.rebind import downcast, rebind_var
from std.memory import MaybeUninit
from fp.algebra._accumulation import _Combine, _FirstPresent
from fp.algebra.protocols import Monoid, _Accumulate, _map_accumulate, _start_as
from fp.algebra.instances import _ListElement
from fp.callables.protocols import UnaryContract, BorrowCallable
from fp.callables._transforms import _Observe
from fp.callables.products import _take_pair
from fp._internal.errors import _CommonError, _ErrorCompatible


trait _Terminal(Movable, Deinitable):
    """A terminal with a generic source boundary, preserving local view origins."""
    comptime Out: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def run[V: Movable & Deinitable](deinit self, var source: V) raises Self.Error -> Self.Out:
        ...


@fieldwise_init
struct _FoldMapRun[F: UnaryContract & Movable & Deinitable, M: Monoid,
                   E: Movable & Deinitable](_Terminal):
    var function: Self.F
    comptime Out = Self.M.Value
    comptime Error = Self.E
    def run[V: Movable & Deinitable](deinit self, var source: V) raises Self.E -> Self.Out:
        return _fold_map[V, Self.F, Self.M, Self.E](self.function^, source^)


@fieldwise_init
struct _FindMapRun[F: UnaryContract & Movable & Deinitable](_Terminal):
    var function: Self.F
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def run[V: Movable & Deinitable](deinit self, var source: V) raises Self.Error -> Self.Out:
        return _find_map(self.function^, source^)


@fieldwise_init
struct _ExtremumRun[T: Movable & Deinitable, C: BorrowCallable, smallest: Bool](_Terminal):
    var function: Self.C
    comptime Out = Optional[Self.T]
    comptime Error = Self.C.Failure
    def run[V: Movable & Deinitable](deinit self, var source: V) raises Self.Error -> Self.Out:
        return _extremum[V, Self.T, Self.C, Self.smallest](self.function^, source^)


def _run_terminal[R: _Terminal, V: Movable & Deinitable](var reduction: R, var source: V
) raises R.Error -> R.Out:
    return reduction^.run(source^)


def _fold_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, M: Monoid,
              E: Movable & Deinitable = _CommonError[F.Error, M.Error]](
    var function: F, var source: V
) raises E -> M.Value:
    comptime assert _ErrorCompatible[E, M.Error] and _ErrorCompatible[E, F.Error]
    return _map_accumulate[V, F, _Combine[M], E](function^, source^, _start_as[E, _Combine[M]]())


def _find_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var source: V
) raises F.Error -> F.Out:
    comptime U = _ListElement[F.Out]
    comptime assert F.Out == Optional[U], "find_map: Optional result required"
    return rebind_var[F.Out](_map_accumulate[V, F, _FirstPresent[U], F.Error](function^, source^, Optional[U]()))


struct _Choose[T: Movable & Deinitable, K: Comparable & Movable & Deinitable, smallest: Bool](_Accumulate):
    comptime Item = Tuple[Self.T, Self.K]
    comptime Acc = Optional[Self.Item]
    @staticmethod
    def start() -> Self.Acc:
        return None
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        if not acc:
            return Optional(item^)
        # Strict comparison preserves the first element on ties. Keys are
        # computed once, including for the first element, and retained by value.
        var better: Bool
        comptime if Self.smallest:
            better = item[1] < acc.value()[1]
        else:
            better = acc.value()[1] < item[1]
        if better:
            return Optional(item^)
        return acc^


def _extremum[V: Movable & Deinitable, T: Movable & Deinitable, C: BorrowCallable, smallest: Bool](
    var function: C, var source: V
) raises C.Failure -> Optional[T]:
    comptime K = downcast[C.Result, Comparable & Movable & Deinitable]
    comptime assert C.Payload == T and K == C.Result
    comptime F = _Observe[T, C, True]
    var result = _map_accumulate[V, F, _Choose[T, K, smallest], C.Failure](
        F(function^), source^, Optional[Tuple[T, K]]())
    if not result:
        return None
    var value_slot = MaybeUninit[T]()
    var key_slot = MaybeUninit[K]()
    _take_pair(result.unsafe_take(), value_slot, key_slot)
    var value = value_slot^.unsafe_assume_init()
    var key = key_slot^.unsafe_assume_init()
    _ = key^
    return Optional(value^)


struct _IntSum(Monoid):
    comptime Value = Int
    @staticmethod
    def empty() -> Int:
        return 0
    @staticmethod
    def combine(var left: Int, var right: Int) -> Int:
        return left + right


struct _SIMDSum[dtype: DType, size: SIMDLength](Monoid):
    comptime Value = SIMD[Self.dtype, Self.size]
    @staticmethod
    def empty() -> Self.Value:
        comptime assert Self.dtype.is_integral() or Self.dtype.is_floating_point(), "sum: numeric dtype required"
        return Self.Value(0)
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        return left + right

# --- terminal syntax (generated) ---
# Generated by scripts/generate_plain_overloads.py; execution lives in iteration.reductions.

def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, F: _Unary[A, R]](ref[o] function: F, var source: V) raises Never -> R where _Source[V].Element == A:
    """Return the first present transformed result, stopping without another pull.

    Parameters:
        A: The callback input type, including its native origins.
        R: The native callback result type.
        o: The origin of the borrowed native callback.
        V: The consumed source or carrier type.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, borrowed in place; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The first present Optional result, or absence; no later element is pulled.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _find_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)

def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](ref[o] function: F, var source: V) raises E -> R where _Source[V].Element == A:
    """Return the first present transformed result, stopping without another pull."""
    return _find_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)

def find_map[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //](var function: F, var source: V) raises F.Error -> F.Out where _Source[V].Element == F.Arg:
    """Return the first present transformed result, stopping without another pull."""
    return _find_map(function^, source^)

def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, M: Monoid, F: _Unary[A, R]](ref[o] function: F, var source: V) raises _CommonError[Never, M.Error] -> M.Value where _Source[V].Element == A:
    """Project and combine in order with a monoid; empty input returns its identity.

    Parameters:
        A: The callback input type, including its native origins.
        R: The native callback result type.
        o: The origin of the borrowed native callback.
        V: The consumed source or carrier type.
        M: The Monoid providing the result type, identity and ordered combination.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, borrowed in place; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The projected values combined in order, or the monoid identity on empty input.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _fold_map[M=M](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)

def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](ref[o] function: F, var source: V) raises _CommonError[E, M.Error] -> M.Value where _Source[V].Element == A:
    """Project and combine in order with a monoid; empty input returns its identity."""
    return _fold_map[M=M](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)

def fold_map[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //, M: Monoid](var function: F, var source: V) raises _CommonError[F.Error, M.Error] -> M.Value where _Source[V].Element == F.Arg:
    """Project and combine in order with a monoid; empty input returns its identity."""
    return _fold_map[M=M](function^, source^)

def combine_all[V: Movable & Deinitable, //, M: Monoid](var source: V) raises _CommonError[Never, M.Error] -> M.Value where _Source[V].Element == M.Value:
    """Combine in order with a monoid; empty input returns its identity.

    Parameters:
        V: The consumed source or carrier type.
        M: The Monoid providing the result type, identity and ordered combination.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The values combined in order, or the monoid identity on empty input.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _fold_map[M=M](_Same[M.Value](), source^)

def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, F: _Borrowing[P, R]](ref[o] function: F, var source: V) raises Never -> Optional[downcast[P, Movable & Deinitable]] where _Source[V].Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
    """Return the element with the smallest key; empty input is absent and ties keep the first.

    Parameters:
        P: The borrowed callback payload type, including its native origins.
        R: The native callback result type.
        o: The origin of the borrowed native callback.
        V: The consumed source or carrier type.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, borrowed in place; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        An Optional containing the element with the smallest key; ties retain the first element.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, Never, F, False, o], smallest=True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)), source^)

def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](ref[o] function: F, var source: V) raises E -> Optional[downcast[P, Movable & Deinitable]] where _Source[V].Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
    """Return the element with the smallest key; empty input is absent and ties keep the first."""
    return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, E, F, True, o], smallest=True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)), source^)

def min_by[C: BorrowCallable, V: Movable & Deinitable, //](var function: C, var source: V) raises C.Failure -> Optional[downcast[C.Payload, Movable & Deinitable]] where _Source[V].Element == downcast[C.Payload, Movable & Deinitable] and conforms_to(C.Result, Comparable & Movable & Deinitable):
    """Return the element with the smallest key; empty input is absent and ties keep the first."""
    return _extremum[T=downcast[C.Payload, Movable & Deinitable], C=C, smallest=True](function^, source^)

def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, F: _Borrowing[P, R]](ref[o] function: F, var source: V) raises Never -> Optional[downcast[P, Movable & Deinitable]] where _Source[V].Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
    """Return the element with the largest key; empty input is absent and ties keep the first.

    Parameters:
        P: The borrowed callback payload type, including its native origins.
        R: The native callback result type.
        o: The origin of the borrowed native callback.
        V: The consumed source or carrier type.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, borrowed in place; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        An Optional containing the element with the largest key; ties retain the first element.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, Never, F, False, o], smallest=False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)), source^)

def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](ref[o] function: F, var source: V) raises E -> Optional[downcast[P, Movable & Deinitable]] where _Source[V].Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
    """Return the element with the largest key; empty input is absent and ties keep the first."""
    return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, E, F, True, o], smallest=False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)), source^)

def max_by[C: BorrowCallable, V: Movable & Deinitable, //](var function: C, var source: V) raises C.Failure -> Optional[downcast[C.Payload, Movable & Deinitable]] where _Source[V].Element == downcast[C.Payload, Movable & Deinitable] and conforms_to(C.Result, Comparable & Movable & Deinitable):
    """Return the element with the largest key; empty input is absent and ties keep the first."""
    return _extremum[T=downcast[C.Payload, Movable & Deinitable], C=C, smallest=False](function^, source^)

def sum[V: Movable & Deinitable, //](var source: V) raises Never -> Int where _Source[V].Element == Int:
    """Add in order from zero, preserving the numeric type and SIMD lanes.

    Parameters:
        V: The consumed source or carrier type.

    Args:
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The ordered sum from zero, preserving the numeric type and SIMD lanes.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _fold_map[M=_IntSum, E=Never](_Same[Int](), source^)

def sum[dtype: DType, size: SIMDLength, V: Movable & Deinitable, //](var source: V) raises Never -> SIMD[dtype, size] where _Source[V].Element == SIMD[dtype, size]:
    """Add in order from zero, preserving the numeric type and SIMD lanes."""
    return _fold_map[M=_SIMDSum[dtype, size], E=Never](_Same[SIMD[dtype, size]](), source^)

def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, F: _Unary[A, R]](ref[o] function: F, var source: V) raises Never -> Int where _Source[V].Element == A and R == Int:
    """Project and add in one pass from zero, without an intermediate collection.

    Parameters:
        A: The callback input type, including its native origins.
        R: The native callback result type.
        o: The origin of the borrowed native callback.
        V: The consumed source or carrier type.
        F: The callback type, retaining its receiver, captures and error contract.

    Args:
        function: The callback, borrowed in place; calls follow the operation's evaluation order.
        source: The source, consumed with its native origins; iterator sources are not restarted.

    Returns:
        The ordered sum of projections from zero, without a mapped intermediate collection.

    Raises:
        The exact callback, monoid or family error; Never for a non-raising operation.
    """
    return _fold_map[M=_IntSum, E=Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)

def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](ref[o] function: F, var source: V) raises E -> Int where _Source[V].Element == A and R == Int:
    """Project and add in one pass from zero, without an intermediate collection."""
    return _fold_map[M=_IntSum, E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)

def sum_by[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //](var function: F, var source: V) raises F.Error -> Int where _Source[V].Element == F.Arg and F.Out == Int:
    """Project and add in one pass from zero, without an intermediate collection."""
    return _fold_map[M=_IntSum, E=F.Error](function^, source^)

def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, F: _Unary[A, R]](ref[o] function: F, var source: V) raises Never -> SIMD[dtype, size] where _Source[V].Element == A and R == SIMD[dtype, size]:
    """Project and add in one pass from zero, without an intermediate collection."""
    return _fold_map[M=_SIMDSum[dtype, size], E=Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)

def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, V: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](ref[o] function: F, var source: V) raises E -> SIMD[dtype, size] where _Source[V].Element == A and R == SIMD[dtype, size]:
    """Project and add in one pass from zero, without an intermediate collection."""
    return _fold_map[M=_SIMDSum[dtype, size], E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)

def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //](var function: F, var source: V) raises F.Error -> SIMD[dtype, size] where _Source[V].Element == F.Arg and F.Out == SIMD[dtype, size]:
    """Project and add in one pass from zero, without an intermediate collection."""
    return _fold_map[M=_SIMDSum[dtype, size], E=F.Error](function^, source^)

# --- end terminal syntax ---
