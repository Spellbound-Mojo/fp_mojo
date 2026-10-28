"""Lazy, independently consumed branches with an explicit buffering policy."""
from std.iter import Iterator, IterableOwned
from std.collections import Deque
from std.memory import ArcPointer, MaybeUninit
from std.os import abort
from std.builtin.rebind import downcast, rebind_var
from fp._internal.exclusive import _ExclusiveCell, _exclusive
from fp.callables.products import _take_pair, _OptionalCell
from fp.callables.protocols import BorrowCallable, UnaryContract
from fp.callables.invoke import RepeatableUnary
from fp.data._result import Result, Ok, Err, _ResultType
from ._advance import _Source, _source, _next_optional
from ._callbacks import _LazyUnary, _LazyPredicate, _apply_lazy_unary, _apply_lazy_predicate


trait _BufferPolicy(Movable, Deinitable):
    comptime bounded: Bool
    def _limit(self) -> Int: ...


@fieldwise_init
struct Unbounded(_BufferPolicy):
    """Retain all queued branch values; backlog can grow without limit."""
    comptime bounded = False
    def _limit(self) -> Int: return 0


@fieldwise_init
struct BufferCapacityError(Copyable, Movable):
    """A non-positive bounded buffer capacity, rejected before source binding."""
    var capacity: Int
    """The rejected capacity."""


struct BoundedFail(_BufferPolicy):
    """Fail both live branches if a sibling queue would exceed capacity."""
    comptime bounded = True
    var _capacity: Int
    def __init__(out self, capacity: Int) raises BufferCapacityError:
        """Validate a positive queue capacity without pulling a source.

        Args:
            capacity: Maximum pending elements per branch, greater than zero.

        Raises:
            BufferCapacityError: The capacity is not positive.
        """
        if capacity <= 0: raise BufferCapacityError(capacity)
        self._capacity = capacity
    def _limit(self) -> Int: return self._capacity


@fieldwise_init
struct BufferLimitExceeded(Copyable, Movable):
    """Terminal shared buffer overflow; payloads already yielded stay yielded."""
    var branch: Int
    """The blocked destination: zero for the first branch, one for the second."""
    var capacity: Int
    """The configured queue limit."""


@fieldwise_init
struct _Routed[A: Movable & Deinitable, B: Movable & Deinitable](Movable):
    var first: Optional[Self.A]
    var second: Optional[Self.B]


trait _Router(Movable, Deinitable):
    comptime Input: Movable & Deinitable
    comptime First: Movable & Deinitable
    comptime Second: Movable & Deinitable
    def route(mut self, var value: Self.Input) -> _Routed[Self.First, Self.Second]: ...


@fieldwise_init
struct _Partition[T: Movable & Deinitable, F: Movable & Deinitable](_Router):
    comptime Input = Self.T
    comptime First = Self.T
    comptime Second = Self.T
    var _function: _OptionalCell[Self.F]

    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)

    def route(mut self, var value: Self.T) -> _Routed[Self.T, Self.T]:
        if _apply_lazy_predicate[Self.T, Self.F](self._function.value(), value):
            return _Routed(Optional(value^), Optional[Self.T]())
        return _Routed(Optional[Self.T](), Optional(value^))


@fieldwise_init
struct _Classify[T: Movable & Deinitable, U: Movable & Deinitable, F: Movable & Deinitable](_Router):
    comptime Input = Self.T
    comptime First = downcast[Self.U, _ResultType].Value
    comptime Second = downcast[Self.U, _ResultType].Error
    var _function: _OptionalCell[Self.F]

    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)

    def route(mut self, var value: Self.T) -> _Routed[Self.First, Self.Second]:
        comptime assert Self.U == Result[Self.First, Self.Second]
        var result = rebind_var[Result[Self.First, Self.Second]](_apply_lazy_unary[Self.T, Self.U, Self.F](self._function.value(), value^))
        if result.is_ok():
            return _Routed(Optional(result^._take_ok()), Optional[Self.Second]())
        return _Routed(Optional[Self.First](), Optional(result^._take_err()))


@fieldwise_init
struct _Unzip[A: Movable & Deinitable, B: Movable & Deinitable](_Router):
    comptime Input = Tuple[Self.A, Self.B]
    comptime First = Self.A
    comptime Second = Self.B
    def route(mut self, var value: Self.Input) -> _Routed[Self.A, Self.B]:
        var first = MaybeUninit[Self.A]()
        var second = MaybeUninit[Self.B]()
        _take_pair(value^, first, second)
        return _Routed(Optional(first^.unsafe_assume_init()), Optional(second^.unsafe_assume_init()))


@fieldwise_init
struct _Upstream[I: Iterator, R: _Router](Movable):
    var source: Self.I
    var router: Self.R


comptime _BranchValue[R: _Router, side: Bool] = R.Second if side else R.First
comptime _BranchItem[T: Movable & Deinitable, P: _BufferPolicy] = Result[T, BufferLimitExceeded] if P.bounded else T


def _queue_pop[T: Movable & Deinitable](mut queue: Deque[T]) -> T:
    # Callers check nonemptiness under exclusive access. Native Deque owns all
    # FIFO movement; an impossible underflow is not iterator exhaustion.
    try: return queue.popleft()
    except: abort("fp.iteration: nonempty branch queue underflow")


def _branch_success[T: Movable & Deinitable, P: _BufferPolicy](var value: T) -> Optional[_BranchItem[T, P]]:
    comptime if P.bounded:
        return Optional(rebind_var[_BranchItem[T, P]](Result[T, BufferLimitExceeded](Ok(value^))))
    else:
        return Optional(rebind_var[_BranchItem[T, P]](value^))


struct _Broker[I: Iterator, R: _Router, P: _BufferPolicy](Movable):
    var upstream: Optional[_Upstream[Self.I, Self.R]]
    var first: Deque[Self.R.First]
    var second: Deque[Self.R.Second]
    var first_live: Bool
    var second_live: Bool
    var first_reported: Bool
    var second_reported: Bool
    var failure: Optional[BufferLimitExceeded]
    var policy: Self.P

    def __init__(out self, var source: Self.I, var router: Self.R, var policy: Self.P):
        self.upstream = Optional(_Upstream(source^, router^))
        self.first = Deque[Self.R.First]()
        self.second = Deque[Self.R.Second]()
        self.first_live = True
        self.second_live = True
        self.first_reported = False
        self.second_reported = False
        self.failure = None
        self.policy = policy^

    def close[side: Bool](mut self):
        comptime if side:
            self.second_live = False
            self.second.clear()
        else:
            self.first_live = False
            self.first.clear()
        if not self.first_live and not self.second_live:
            self.upstream = None

    def _fail(mut self, side: Int):
        self.failure = Optional(BufferLimitExceeded(side, self.policy._limit()))
        self.upstream = None
        self.first.clear()
        self.second.clear()

    def _terminal[side: Bool](mut self) -> Optional[_BranchItem[_BranchValue[Self.R, side], Self.P]]:
        comptime if Self.P.bounded:
            if self.failure:
                var reported = self.second_reported if side else self.first_reported
                if not reported:
                    comptime if side: self.second_reported = True
                    else: self.first_reported = True
                    return Optional(rebind_var[_BranchItem[_BranchValue[Self.R, side], Self.P]](
                        Result[_BranchValue[Self.R, side], BufferLimitExceeded](Err(self.failure.value().copy()))))
        return None

    def pull[side: Bool](mut self) -> Optional[_BranchItem[_BranchValue[Self.R, side], Self.P]]:
        comptime assert Self.I.Element == Self.R.Input
        comptime if side:
            if not self.second_live: return None
            if self.second:
                return _branch_success[_BranchValue[Self.R, side], Self.P](rebind_var[_BranchValue[Self.R, side]](_queue_pop(self.second)))
        else:
            if not self.first_live: return None
            if self.first:
                return _branch_success[_BranchValue[Self.R, side], Self.P](rebind_var[_BranchValue[Self.R, side]](_queue_pop(self.first)))
        while self.upstream:
            var input = _next_optional[Self.R.Input](self.upstream.value().source)
            if not input:
                self.upstream = None
                break
            var routed = self.upstream.value().router.route(input.unsafe_take())
            # Check both destinations before publishing either field of unzip.
            # The requested branch has no backlog and receives its value directly.
            comptime if Self.P.bounded:
                if side and self.first_live and routed.first and len(self.first) >= self.policy._limit():
                    self._fail(0)
                    return self._terminal[side]()
                if not side and self.second_live and routed.second and len(self.second) >= self.policy._limit():
                    self._fail(1)
                    return self._terminal[side]()
            comptime if side:
                if self.first_live and routed.first: self.first.append(routed.first.unsafe_take())
                if routed.second:
                    return _branch_success[_BranchValue[Self.R, side], Self.P](rebind_var[_BranchValue[Self.R, side]](routed.second.unsafe_take()))
            else:
                if self.second_live and routed.second: self.second.append(routed.second.unsafe_take())
                if routed.first:
                    return _branch_success[_BranchValue[Self.R, side], Self.P](rebind_var[_BranchValue[Self.R, side]](routed.first.unsafe_take()))
        return self._terminal[side]()


@fieldwise_init
struct _Branch[E: Movable & Deinitable, I: Iterator, R: _Router, P: _BufferPolicy, side: Bool](Iterator, IterableOwned):
    comptime Element = Self.E
    comptime IteratorOwnedType = Self
    var owner: ArcPointer[_ExclusiveCell[_Broker[Self.I, Self.R, Self.P]]]
    var closed: Bool
    def __iter__(var self) -> Self: return self^
    def __next__(mut self) raises StopIteration -> Self.Element:
        if self.closed: raise StopIteration()
        var access = _exclusive(self.owner)
        var result = access.value().pull[Self.side]()
        if result:
            comptime assert Self.E == _BranchItem[_BranchValue[Self.R, Self.side], Self.P]
            return rebind_var[Self.E](result.unsafe_take())
        raise StopIteration()
    def close(mut self):
        """Release this branch's backlog without evaluating more of the source."""
        if not self.closed:
            var access = _exclusive(self.owner)
            access.value().close[Self.side]()
            self.closed = True
    def __deinit__(deinit self):
        self.close()


def _branches[A: Movable & Deinitable, B: Movable & Deinitable, I: Iterator, R: _Router, P: _BufferPolicy](var source: I, var router: R, var policy: P) -> Tuple[_Branch[_BranchItem[A, P], I, R, P, False], _Branch[_BranchItem[B, P], I, R, P, True]]:
    comptime assert R.First == A and R.Second == B
    var owner = ArcPointer(_ExclusiveCell(Int32(0), _Broker(source^, router^, policy^)))
    return (_Branch[_BranchItem[A, P], I, R, P, False](owner, False), _Branch[_BranchItem[B, P], I, R, P, True](owner^, False))


# Public syntax follows below; every operation shares the same broker.

comptime PartitionBranches[T: Movable & Deinitable, I: Iterator, F: Movable & Deinitable, P: _BufferPolicy] = Tuple[_Branch[_BranchItem[T, P], I, _Partition[T, F], P, False], _Branch[_BranchItem[T, P], I, _Partition[T, F], P, True]]
"""Two native move-only iterator handles, accepted first and rejected second.

Parameters:
    T: The source element type.
    I: The normalized source iterator.
    F: The concrete predicate type, retaining its captures and origins.
    P: The explicit Unbounded or BoundedFail policy.
"""


comptime PartitionMapBranches[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, F: Movable & Deinitable, P: _BufferPolicy] = Tuple[_Branch[_BranchItem[downcast[U, _ResultType].Value, P], I, _Classify[T, U, F], P, False], _Branch[_BranchItem[downcast[U, _ResultType].Error, P], I, _Classify[T, U, F], P, True]]
"""Two native move-only handles, classified Ok payloads first and Err payloads second.

Parameters:
    T: The source element type.
    U: The classifier's exact Result type, including both payload origins.
    I: The normalized source iterator.
    F: The concrete classifier type.
    P: The explicit Unbounded or BoundedFail policy.
"""

comptime UnzipBranches[A: Movable & Deinitable, B: Movable & Deinitable, I: Iterator, P: _BufferPolicy] = Tuple[_Branch[_BranchItem[A, P], I, _Unzip[A, B], P, False], _Branch[_BranchItem[B, P], I, _Unzip[A, B], P, True]]
"""Two native move-only handles for the fields of native pairs.

Parameters:
    A: The first tuple field type.
    B: The second tuple field type.
    I: The normalized source iterator.
    P: The explicit Unbounded or BoundedFail policy.
"""

# --- iterator expansion syntax (generated) ---
# Generated by scripts/generate_plain_overloads.py; algorithms live in the operation owners.

def partition[T: Movable & Deinitable, V: Movable & Deinitable, P: _BufferPolicy](var predicate: def(T) thin -> Bool, var source: V, *, var buffer: P) -> PartitionBranches[T, _Source[V], def(T) thin -> Bool, P] where _Source[V].Element == T:
    """Lazily split accepted and rejected elements into independent iterators.

    Construction pulls nothing and each source item is classified once. Branches are move-only.
    Unbounded queues retain every pending value; BoundedFail yields Result elements,
    discards all queued values on overflow and gives each live branch one terminal Err.
    Close a branch to release its queue without draining upstream. Access is sequential;
    reentrant or overlapping access aborts before a second mutable state borrow.

    Parameters:
        T: The source element type, including origins.
        V: The consumed native iterator or owned collection type.
        P: The admitted type parameter.

    Args:
        predicate: The predicate, borrowing each candidate; the selected overload borrows or owns the predicate.
        source: The source, consumed at its current position.
        buffer: The required buffering policy; there is no implicit default.

    Returns:
        PartitionBranches[T, _Source[V], def(T) thin -> Bool, P] with the ownership, timing and empty-input behavior described above.
    """
    return _branches[T, T](_source(source^), _Partition[T, def(T) thin -> Bool](predicate), buffer^)

def partition[T: Movable & Deinitable, V: Movable & Deinitable, P: _BufferPolicy, //, F: _LazyPredicate[T]](var predicate: F, var source: V, *, var buffer: P) -> PartitionBranches[T, _Source[V], F, P] where _Source[V].Element == T:
    """Lazily split accepted and rejected elements into independent iterators.
    """
    return _branches[T, T](_source(source^), _Partition[T, F](predicate^), buffer^)

def partition[C: BorrowCallable, V: Movable & Deinitable, P: _BufferPolicy](var predicate: C, var source: V, *, var buffer: P) -> PartitionBranches[downcast[C.Payload, Movable & Deinitable], _Source[V], C, P] where _Source[V].Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and C.Failure == Never:
    """Lazily split accepted and rejected elements into independent iterators.
    """
    return _branches[downcast[C.Payload, Movable & Deinitable], downcast[C.Payload, Movable & Deinitable]](_source(source^), _Partition[downcast[C.Payload, Movable & Deinitable], C](predicate^), buffer^)

def partition_map[T: Movable & Deinitable, U: Movable & Deinitable, V: Movable & Deinitable, P: _BufferPolicy](var function: def(var T) thin -> U, var source: V, *, var buffer: P) -> PartitionMapBranches[T, U, _Source[V], def(var T) thin -> U, P] where _Source[V].Element == T and conforms_to(U, _ResultType):
    """Lazily route Result payloads into independent Ok and Err iterators.

    Construction pulls nothing and each source item is classified once. Branches are move-only.
    Unbounded queues retain every pending value; BoundedFail yields Result elements,
    discards all queued values on overflow and gives each live branch one terminal Err.
    Close a branch to release its queue without draining upstream. Access is sequential;
    reentrant or overlapping access aborts before a second mutable state borrow.

    Parameters:
        T: The source element type, including origins.
        U: The callback result type, including origins.
        V: The consumed native iterator or owned collection type.
        P: The admitted type parameter.

    Args:
        function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.
        source: The source, consumed at its current position.
        buffer: The required buffering policy; there is no implicit default.

    Returns:
        PartitionMapBranches[T, U, _Source[V], def(var T) thin -> U, P] with the ownership, timing and empty-input behavior described above.
    """
    return _branches[downcast[U, _ResultType].Value, downcast[U, _ResultType].Error](_source(source^), _Classify[T, U, def(var T) thin -> U](function), buffer^)

def partition_map[T: Movable & Deinitable, U: Movable & Deinitable, V: Movable & Deinitable, P: _BufferPolicy, //, F: _LazyUnary[T, U]](var function: F, var source: V, *, var buffer: P) -> PartitionMapBranches[T, U, _Source[V], F, P] where _Source[V].Element == T and conforms_to(U, _ResultType):
    """Lazily route Result payloads into independent Ok and Err iterators.
    """
    return _branches[downcast[U, _ResultType].Value, downcast[U, _ResultType].Error](_source(source^), _Classify[T, U, F](function^), buffer^)

def partition_map[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, P: _BufferPolicy](var function: F, var source: V, *, var buffer: P) -> PartitionMapBranches[F.Arg, F.Out, _Source[V], F, P] where _Source[V].Element == F.Arg and conforms_to(F.Out, _ResultType) and F.Error == Never and RepeatableUnary[F]:
    """Lazily route Result payloads into independent Ok and Err iterators.
    """
    return _branches[downcast[F.Out, _ResultType].Value, downcast[F.Out, _ResultType].Error](_source(source^), _Classify[F.Arg, F.Out, F](function^), buffer^)

def unzip[A: Movable & Deinitable, B: Movable & Deinitable, V: Movable & Deinitable, P: _BufferPolicy](var source: V, *, var buffer: P) -> UnzipBranches[A, B, _Source[V], P] where _Source[V].Element == Tuple[A, B]:
    """Lazily split native tuple fields, checking both queues before publishing either field.

    Construction pulls nothing and each source item is classified once. Branches are move-only.
    Unbounded queues retain every pending value; BoundedFail yields Result elements,
    discards all queued values on overflow and gives each live branch one terminal Err.
    Close a branch to release its queue without draining upstream. Access is sequential;
    reentrant or overlapping access aborts before a second mutable state borrow.

    Parameters:
        A: The first callback argument type.
        B: The second callback argument type.
        V: The consumed native iterator or owned collection type.
        P: The admitted type parameter.

    Args:
        source: The source, consumed at its current position.
        buffer: The required buffering policy; there is no implicit default.

    Returns:
        UnzipBranches[A, B, _Source[V], P] with the ownership, timing and empty-input behavior described above.
    """
    return _branches[A, B](_source(source^), _Unzip[A, B](), buffer^)
# --- end iterator expansion syntax ---
