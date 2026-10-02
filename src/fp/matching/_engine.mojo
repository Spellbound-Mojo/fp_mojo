"""The single-subject matcher: one loop over an explicit stack of pending values.

Everything a value's match does is planned at compile time from the clause
types: which clauses are tried for each constructor, which fields each one has
evaluated, and in what order. A frame is a value, a step number in that plan and
the height of the value stack where its children's results start. A child that
completes in one step, such as a leaf, is evaluated without a frame. A declining
guarded clause keeps the results it had evaluated, so no child is evaluated
twice for one value.
"""
from std.memory import MaybeUninit
from std.builtin.rebind import rebind_var, downcast
from std.collections import Dict
from std.os import abort
from fp.adt.data import Value, Data, Node, _shape, _FIELD, _ONE, _MANY, _MAYBE, _admit_data
from fp.matching.clauses import Next, _Continuation, _Declinable
from fp._internal.errors import _ErrorCompatible, _forward


trait _Signature:
    """A clause's native signature: one to three parameters, a result and an error."""

    comptime arity: Int
    comptime First: AnyType
    comptime Second: AnyType
    comptime Third: AnyType
    comptime Out: Value
    comptime Err: Value
    comptime Fn: ImplicitlyCopyable & Deinitable


struct _Absent(ImplicitlyCopyable):
    """The type of a parameter a signature does not have, and of an absent context."""

    def __init__(out self):
        pass


struct _Sig1[A: AnyType, O: Value, E: Value](_Signature):
    comptime arity = 1
    comptime First = Self.A
    comptime Second = _Absent
    comptime Third = _Absent
    comptime Out = Self.O
    comptime Err = Self.E
    comptime Fn = def(Self.A) raises Self.E thin -> Self.O


struct _Sig2[A: AnyType, B: AnyType, O: Value, E: Value](_Signature):
    comptime arity = 2
    comptime First = Self.A
    comptime Second = Self.B
    comptime Third = _Absent
    comptime Out = Self.O
    comptime Err = Self.E
    comptime Fn = def(Self.A, Self.B) raises Self.E thin -> Self.O


struct _Sig3[A: AnyType, B: AnyType, C: AnyType, O: Value, E: Value](_Signature):
    comptime arity = 3
    comptime First = Self.A
    comptime Second = Self.B
    comptime Third = Self.C
    comptime Out = Self.O
    comptime Err = Self.E
    comptime Fn = def(Self.A, Self.B, Self.C) raises Self.E thin -> Self.O


trait _ClauseSet(Movable, Deinitable):
    """Clauses in order: their signatures, and the function of clause `j`."""

    comptime count: Int
    comptime Sig[j: Int]: _Signature

    def function[j: Int](self) -> Self.Sig[j].Fn:
        ...


struct _Nil(_ClauseSet):
    """No more clauses."""

    comptime count = 0
    comptime Sig[j: Int]: _Signature = _Sig1[_Absent, _NoResult, Never]

    def __init__(out self):
        pass

    def function[j: Int](self) -> Self.Sig[j].Fn:
        abort("fp.match: no clause")


struct _Cons[S: _Signature, Rest: _ClauseSet](_ClauseSet):
    """A clause followed by the remaining clauses."""

    comptime count = 1 + Self.Rest.count
    comptime Sig[j: Int]: _Signature = Self.S if j == 0 else Self.Rest.Sig[j - 1]
    var head: Self.S.Fn
    var rest: Self.Rest

    def __init__(out self, head: Self.S.Fn, var rest: Self.Rest):
        self.head = head
        self.rest = rest^

    def function[j: Int](self) -> Self.Sig[j].Fn:
        comptime if j == 0:
            return rebind[Self.Sig[j].Fn](self.head)
        else:
            return rebind[Self.Sig[j].Fn](self.rest.function[j - 1]())


def _call[C: _ClauseSet, j: Int, E: Value](clauses: C, a: C.Sig[j].First) raises E -> C.Sig[j].Out:
    comptime T = C.Sig[j]
    return _forward[E](rebind[def(T.First) raises T.Err thin -> T.Out](clauses.function[j]()), a)


def _call[C: _ClauseSet, j: Int, E: Value](clauses: C, a: C.Sig[j].First, b: C.Sig[j].Second) raises E -> C.Sig[j].Out:
    comptime T = C.Sig[j]
    return _forward[E](rebind[def(T.First, T.Second) raises T.Err thin -> T.Out](clauses.function[j]()), a, b)


def _call[C: _ClauseSet, j: Int, E: Value](
    clauses: C, a: C.Sig[j].First, b: C.Sig[j].Second, c: C.Sig[j].Third
) raises E -> C.Sig[j].Out:
    comptime T = C.Sig[j]
    return _forward[E](rebind[def(T.First, T.Second, T.Third) raises T.Err thin -> T.Out](clauses.function[j]()), a, b, c)


struct _NoResult(Movable):
    """No clause produces a value."""
    pass


comptime _Inner[O: Value]: Value = downcast[O, _Declinable].Payload if conforms_to(O, _Declinable) else O
"""A clause's result with any guard removed."""

comptime _Pick[O: Value, Rest: Value]: Value = Rest if conforms_to(_Inner[O], _Continuation) else _Inner[O]
"""The first clause result that is a value rather than `Next`."""


# ----------------------------------------------------------------- fields

comptime _RAW = 0
comptime _FOLD = 1
comptime _FOLD_MANY = 2
comptime _FOLD_MAYBE = 3
comptime _BAD = 4


def _mode[F: Data, R: Value, Stored: AnyType, Wanted: AnyType]() -> Int:
    """How a stored field reaches a clause that declares it as `Wanted`."""
    comptime if Stored == Node[F] and Wanted == R:
        return _FOLD
    elif Stored == List[Node[F]] and Wanted == List[R]:
        return _FOLD_MANY
    elif Stored == Optional[Node[F]] and Wanted == Optional[R]:
        return _FOLD_MAYBE
    elif Stored == Wanted:
        return _RAW
    return _BAD


def _same_constructor[A: AnyType, B: AnyType]() -> Bool:
    comptime if not reflect[A].is_struct() or not reflect[B].is_struct():
        return False
    else:
        return reflect[A].base_name() == reflect[B].base_name() and reflect[A].field_count() == reflect[B].field_count()


def _children[F: Data, Stored: AnyType](value: Stored) -> Int:
    """The number of children a stored constructor holds."""
    var count = 0
    comptime Fs = reflect[Stored].field_types()
    comptime for f in range(reflect[Stored].field_count()):
        comptime shape = _shape[F, Fs[f]]()
        comptime if shape == _ONE:
            count += 1
        elif shape == _MANY:
            count += len(rebind[List[Node[F]]](reflect[Stored].field_ref[f](value)))
        elif shape == _MAYBE:
            count += 1 if rebind[Optional[Node[F]]](reflect[Stored].field_ref[f](value)) else 0
    return count


def _child[F: Data, Stored: AnyType](ref value: Stored, index: Int) -> Pointer[Node[F], ImmUntrackedOrigin]:
    """Child `index` of a stored constructor, in field order."""
    var seen = 0
    comptime Fs = reflect[Stored].field_types()
    comptime for f in range(reflect[Stored].field_count()):
        comptime shape = _shape[F, Fs[f]]()
        comptime if shape == _ONE:
            if seen == index:
                return Pointer(to=rebind[Node[F]](reflect[Stored].field_ref[f](value))).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
            seen += 1
        elif shape == _MANY:
            ref items = rebind[List[Node[F]]](reflect[Stored].field_ref[f](value))
            if index < seen + len(items):
                return Pointer(to=items.unsafe_get(index - seen)).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
            seen += len(items)
        elif shape == _MAYBE:
            ref item = rebind[Optional[Node[F]]](reflect[Stored].field_ref[f](value))
            if item:
                if seen == index:
                    return Pointer(to=item.unsafe_value()).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
                seen += 1
    abort("fp.match: child index out of range")


def _size[F: Data, Stored: AnyType, f: Int](value: Stored) -> Int:
    """How many children field `f` of a stored constructor holds."""
    comptime shape = _shape[F, reflect[Stored].field_types()[f]]()
    comptime if shape == _ONE:
        return 1
    elif shape == _MANY:
        return len(rebind[List[Node[F]]](reflect[Stored].field_ref[f](value)))
    elif shape == _MAYBE:
        return 1 if rebind[Optional[Node[F]]](reflect[Stored].field_ref[f](value)) else 0
    return 0


def _unchanged[F: Data, Stored: AnyType](new: Stored, old: Stored) -> Bool:
    """Whether a rebuilt constructor holds the same children as the stored one."""
    for k in range(_children[F](old)):
        if not (_child[F](new, k)[] is _child[F](old, k)[]):
            return False
    return True


# ----------------------------------------------------------------- plans
#
# The candidates for constructor `i` are the clauses that apply to it, in order,
# up to the first that cannot decline; in a rewrite, the rebuild fallback
# (`C.count`) follows when every clause can decline. Candidate `t` evaluates the
# fields it takes evaluated that no earlier candidate evaluated, in field order,
# and their results are pushed on the value stack. Which results a frame holds,
# and in what order, is therefore known at compile time for every candidate.
#
# A frame's state is a step number: `t * (fields + 1) + f` evaluates field `f`
# for candidate `t`, and `t * (fields + 1) + fields` calls the candidate.

def _candidate[F: Data, C: _ClauseSet, rewrite: Bool, i: Int, t: Int]() -> Int:
    """The clause of candidate `t` for constructor `i`, `C.count` for the rebuild fallback, or -1."""
    var seen = 0
    comptime for j in range(C.count):
        comptime if _applies[F, C, i, j]():
            if seen == t:
                return j
            seen += 1
            comptime if not _guarded[C, j]():
                return -1
    comptime if rewrite:
        if seen == t:
            return C.count
    return -1


def _candidates[F: Data, C: _ClauseSet, rewrite: Bool, i: Int]() -> Int:
    var count = 0
    comptime for j in range(C.count):
        comptime if _applies[F, C, i, j]():
            count += 1
            comptime if not _guarded[C, j]():
                return count
    comptime if rewrite:
        return count + 1
    return count


def _folds[F: Data, C: _ClauseSet, R: Value, rewrite: Bool, i: Int, t: Int, f: Int]() -> Bool:
    """Whether candidate `t` takes field `f` of constructor `i` evaluated."""
    comptime Stored = F.Layer[Node[F]].Case[i]
    comptime In = reflect[Stored].field_types()
    comptime j = _candidate[F, C, rewrite, i, t]()
    comptime if j < 0:
        return False
    elif rewrite or j == C.count:
        # A rewrite evaluates every child before any clause sees the value.
        return _shape[F, In[f]]() != _FIELD
    else:
        comptime A = C.Sig[j].First
        comptime if A == Node[F]:
            return False
        else:
            return _mode[F, R, In[f], reflect[A].field_types()[f]]() != _RAW


def _takes[F: Data, C: _ClauseSet, R: Value, rewrite: Bool, i: Int, t: Int]() -> Bool:
    """Whether candidate `t` takes any field evaluated."""
    comptime for f in range(reflect[F.Layer[Node[F]].Case[i]].field_count()):
        comptime if _folds[F, C, R, rewrite, i, t, f]():
            return True
    return False


def _new_at[F: Data, C: _ClauseSet, R: Value, rewrite: Bool, i: Int, t: Int, f: Int]() -> Bool:
    """Whether candidate `t` is the first to take field `f` evaluated, so evaluates it."""
    comptime if not _folds[F, C, R, rewrite, i, t, f]():
        return False
    comptime for s in range(t):
        comptime if _folds[F, C, R, rewrite, i, s, f]():
            return False
    return True


def _step_after[F: Data, C: _ClauseSet, R: Value, rewrite: Bool, i: Int, t: Int, f: Int]() -> Int:
    """The step that follows field `f` of candidate `t`: the next field it evaluates, or its call."""
    comptime fields = reflect[F.Layer[Node[F]].Case[i]].field_count()
    comptime for g in range(fields):
        comptime if g > f and _new_at[F, C, R, rewrite, i, t, g]():
            return t * (fields + 1) + g
    return t * (fields + 1) + fields


def _offset[F: Data, C: _ClauseSet, R: Value, rewrite: Bool, i: Int, t: Int, f: Int](value: F.Layer[Node[F]].Case[i]) -> Int:
    """Where the results of field `f` start among a frame's results, at candidate `t`."""
    comptime fields = reflect[F.Layer[Node[F]].Case[i]].field_count()
    var offset = 0
    comptime for s in range(t + 1):
        comptime for g in range(fields):
            comptime if _new_at[F, C, R, rewrite, i, s, g]():
                comptime if _new_at[F, C, R, rewrite, i, s, f]() and g >= f:
                    return offset
                offset += _size[F, F.Layer[Node[F]].Case[i], g](value)
    abort("fp.match: field not evaluated")


def _argument[F: Data, C: _ClauseSet, R: Value, rewrite: Bool, i: Int, t: Int, A: AnyType, keep: Bool](
    value: F.Layer[Node[F]].Case[i], mut values: List[R], base: Int
) -> downcast[A, Value]:
    """The argument of candidate `t`: evaluated fields from the value stack, the others copied.

    Without `keep` the frame's results are popped, last first: the ones the
    candidate takes move into the argument and the others are released. With
    `keep` (a candidate that may decline) they are copied and stay.
    """
    comptime Stored = F.Layer[Node[F]].Case[i]
    comptime In = reflect[Stored].field_types()
    comptime Want = reflect[A].field_types()
    comptime fields = reflect[Stored].field_count()
    comptime assert conforms_to(A, Value), "fp.match: a clause parameter that evaluates fields must be Movable"
    var slot = MaybeUninit[downcast[A, Value]]()
    var memory = slot.unsafe_ptr().unsafe_bitcast[UInt8]()
    comptime for f in range(fields):
        comptime if not _folds[F, C, R, rewrite, i, t, f]():
            comptime T = downcast[Want[f], Movable]
            comptime assert conforms_to(In[f], Copyable), (
                "fp.match: field " + String(reflect[Stored].field_names()[f]) + " of " + reflect[Stored].base_name()
                + " is copied into the clause argument and must be Copyable")
            var target = memory.unsafe_offset(reflect[A].field_offset[index=f]()).unsafe_bitcast[T]()
            target.unsafe_write(rebind_var[T](rebind[downcast[In[f], Copyable]](reflect[Stored].field_ref[f](value)).copy()))
    comptime if keep:
        comptime assert conforms_to(R, Copyable), "fp.match: a guarded clause that evaluates fields needs a Copyable result"
        comptime for f in range(fields):
            comptime if _folds[F, C, R, rewrite, i, t, f]():
                comptime T = downcast[Want[f], Movable]
                comptime shape = _shape[F, In[f]]()
                var target = memory.unsafe_offset(reflect[A].field_offset[index=f]()).unsafe_bitcast[T]()
                var at = base + _offset[F, C, R, rewrite, i, t, f](value)
                comptime if shape == _ONE:
                    target.unsafe_write(rebind_var[T](_copy(values, at)))
                elif shape == _MANY:
                    var count = _size[F, Stored, f](value)
                    var items = List[R](capacity=count)
                    for k in range(count):
                        items.append(_copy(values, at + k))
                    target.unsafe_write(rebind_var[T](items^))
                else:
                    var item = Optional[R]()
                    if _size[F, Stored, f](value) > 0:
                        item = Optional[R](_copy(values, at))
                    target.unsafe_write(rebind_var[T](item^))
    else:
        comptime for sr in range(t + 1):
            comptime s = t - sr
            comptime for gr in range(fields):
                comptime g = fields - 1 - gr
                comptime if _new_at[F, C, R, rewrite, i, s, g]():
                    comptime if _folds[F, C, R, rewrite, i, t, g]():
                        comptime T = downcast[Want[g], Movable]
                        comptime shape = _shape[F, In[g]]()
                        var target = memory.unsafe_offset(reflect[A].field_offset[index=g]()).unsafe_bitcast[T]()
                        comptime if shape == _ONE:
                            target.unsafe_write(rebind_var[T](values.pop()))
                        elif shape == _MANY:
                            var count = _size[F, Stored, g](value)
                            var items = List[R](capacity=count)
                            for _ in range(count):
                                items.append(values.pop())
                            items.reverse()
                            target.unsafe_write(rebind_var[T](items^))
                        else:
                            var item = Optional[R]()
                            if _size[F, Stored, g](value) > 0:
                                item = Optional[R](values.pop())
                            target.unsafe_write(rebind_var[T](item^))
                    else:
                        for _ in range(_size[F, Stored, g](value)):
                            _ = values.pop()
    return slot^.unsafe_assume_init()


def _copy[R: Value](values: List[R], at: Int) -> R:
    return rebind_var[R](rebind[downcast[R, Copyable]](values.unsafe_get(at)).copy())


# ----------------------------------------------------------------- admission

def _name[T: AnyType]() -> String:
    """A type's name for a diagnostic."""
    return String(reflect[T].name())


def _applies[F: Data, C: _ClauseSet, i: Int, j: Int]() -> Bool:
    """Whether clause `j` is a candidate for constructor `i`."""
    comptime S = F.Layer[Node[F]]
    return C.Sig[j].First == Node[F] or _same_constructor[C.Sig[j].First, S.Case[i]]()


def _guarded[C: _ClauseSet, j: Int]() -> Bool:
    return conforms_to(C.Sig[j].Out, _Declinable)


def _covered[F: Data, C: _ClauseSet, i: Int]() -> Bool:
    comptime for j in range(C.count):
        comptime if _applies[F, C, i, j]() and not _guarded[C, j]():
            return True
    return False


def _reachable[F: Data, C: _ClauseSet, j: Int]() -> Bool:
    """Whether some constructor reaches clause `j` before an earlier clause that cannot decline."""
    comptime S = F.Layer[Node[F]]
    comptime for i in range(S.count):
        comptime if _applies[F, C, i, j]():
            var blocked = False
            comptime for k in range(j):
                comptime if _applies[F, C, i, k]() and not _guarded[C, k]():
                    blocked = True
            if not blocked:
                return True
    return False


def _admit[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool]() -> Bool:
    """The compile-time rules of a match; each failure names the clause or constructor."""
    comptime assert _admit_data[F]()
    comptime S = F.Layer[Node[F]]
    comptime assert not (R == _NoResult), "fp.match: every clause continues with Next; at least one must produce a value"
    comptime for j in range(C.count):
        comptime A = C.Sig[j].First
        comptime known = A == Node[F] or _first_constructor[F, A]() >= 0
        comptime assert known, (
            "fp.match: clause " + String(j) + " takes " + _name[A]() + ", which is not a constructor of "
            + _name[F]() + " or " + _name[Node[F]]())
        comptime if known and not (A == Node[F]):
            comptime Stored = S.Case[_first_constructor[F, A]()]
            comptime In = reflect[Stored].field_types()
            comptime Want = reflect[A].field_types()
            comptime for f in range(reflect[Stored].field_count()):
                comptime assert _mode[F, R, In[f], Want[f]]() != _BAD, (
                    "fp.match: clause " + String(j) + " declares field " + String(reflect[Stored].field_names()[f])
                    + " of " + reflect[Stored].base_name() + " as " + _name[Want[f]]() + "; it must be "
                    + _name[In[f]]() + ", or the result type " + _name[R]() + " for a recursive field")
        comptime V = _Inner[C.Sig[j].Out]
        comptime assert V == R or V == Next[Node[F]], (
            "fp.match: clause " + String(j) + " returns " + _name[V]() + "; every clause returns "
            + _name[R]() + " or Next")
        comptime assert _ErrorCompatible[E, C.Sig[j].Err], (
            "fp.match: clause " + String(j) + " raises a different error type from an earlier clause; every clause raises one error type or none")
        comptime assert _reachable[F, C, j](), "fp.match: clause " + String(j) + " is never selected: an earlier clause for the same constructors cannot decline"
        comptime if not (X == _Absent):
            comptime assert C.Sig[j].Second == X, (
                "fp.match: clause " + String(j) + " takes " + _name[C.Sig[j].Second]() + " as its second parameter; the context is "
                + _name[X]())
    comptime if rewrite:
        comptime for j in range(C.count):
            comptime assert not (C.Sig[j].First == Node[F]), (
                "fp.rewrite: clause " + String(j) + " takes the whole value; a rewrite clause takes a constructor")
    else:
        comptime for i in range(S.count):
            comptime assert _covered[F, C, i](), (
                "fp.match: constructor " + reflect[S.Case[i]].base_name() + " has no clause that cannot decline")
    return True


def _first_constructor[F: Data, A: AnyType]() -> Int:
    comptime S = F.Layer[Node[F]]
    comptime for i in range(S.count):
        comptime if _same_constructor[A, S.Case[i]]():
            return i
    return -1


# ----------------------------------------------------------------- the loop

struct _Frame[F: Data](Movable):
    """A value being matched: which value, which step it is at, and where its results start.

    Frames are kept small (32 bytes): a deep value keeps one per level on the
    stack, and their size decides how much of it stays in cache.
    """

    var handle: Pointer[Node[Self.F], ImmUntrackedOrigin]
    """The `Node` inside the subject; an owned value (after `Next`) is on top of the owned stack instead."""
    var base: Int
    """The height of the value stack when the value started."""
    var sub: Int
    """The next element of a list field being evaluated."""
    var pc: Int32
    var ctor: UInt16
    var owned: Bool
    var shared: Bool
    """Whether the value is shared, so its result is remembered under its address."""

    def __init__(out self, handle: Pointer[Node[Self.F], ImmUntrackedOrigin]):
        self.handle = handle
        self.base = 0
        self.sub = 0
        self.pc = 0
        self.ctor = 0
        self.owned = False
        self.shared = False


@always_inline
def _node_of[F: Data](frame: _Frame[F], owned: List[Node[F]]) -> Pointer[Node[F], ImmUntrackedOrigin]:
    """The value a frame matches; an owned value is on top of the owned stack."""
    if frame.owned:
        return Pointer(to=owned.unsafe_get(len(owned) - 1)).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    return frame.handle


@always_inline
def _key[F: Data](node: Node[F]) -> Int:
    """The memo key of a shared value: the address of its cell."""
    return Int(Pointer(to=node._cell[]))


# What a frame's steps produced.
comptime _CHILD = 1   # It needs the child in `child` evaluated first.
comptime _DONE = 2    # Its result is on top of the value stack.
comptime _AGAIN = 3   # It continued with a smaller value (`Next`); step it again.


@always_inline
def _enter[F: Data, C: _ClauseSet, R: Value, rewrite: Bool](mut frame: _Frame[F], owned: List[Node[F]]):
    """Start a frame again at the first step of its constructor's first candidate."""
    comptime S = F.Layer[Node[F]]
    ref layer = _node_of(frame, owned)[]._cell[].layer
    frame.sub = 0
    comptime for i in range(S.count):
        if S.is_case[i](layer):
            frame.ctor = UInt16(i)
            frame.pc = Int32(_step_after[F, C, R, rewrite, i, 0, -1]())
            return
    abort("fp.match: no active constructor")


# What starting a value produced, besides the step outcomes.
comptime _KNOWN = 4   # A shared value already matched: its result is on the value stack.


@always_inline
def _start[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool, rewrite: Bool](
    mut frame: _Frame[F], mut values: List[R], memo: Dict[Int, Memo], mut owned: List[Node[F]], clauses: C, context: X,
    mut child: Pointer[Node[F], ImmUntrackedOrigin]
) raises E -> Int:
    """Start a frame and run its first steps, dispatching on its constructor once.

    A shared value already matched has its result pushed instead. This is
    `_enter` followed by `_advance` with one dispatch instead of two: most values
    complete in their first steps, so the second dispatch would cost every value.
    """
    comptime S = F.Layer[Node[F]]
    comptime if memoize:
        if frame.handle[]._cell.count() > 1:
            var known = memo.get(_key(frame.handle[]))
            if known:
                values.append(rebind_var[R](known.take()))
                return _KNOWN
            frame.shared = True
    ref layer = frame.handle[]._cell[].layer
    frame.base = len(values)
    comptime for i in range(S.count):
        if S.is_case[i](layer):
            frame.ctor = UInt16(i)
            frame.pc = Int32(_step_after[F, C, R, rewrite, i, 0, -1]())
            var outcome = _steps[F, C, R, E, X, rewrite, i](frame, values, owned, clauses, context, child)
            if outcome != _AGAIN:
                return outcome
            return _advance[F, C, R, E, X, rewrite](frame, values, owned, clauses, context, child)
    abort("fp.match: no active constructor")


@always_inline
def _finish[F: Data, R: Value, Memo: Copyable & Deinitable, memoize: Bool](
    frame: _Frame[F], values: List[R], mut memo: Dict[Int, Memo], mut owned: List[Node[F]]
):
    """A frame completed: remember a shared value's result and release an owned value."""
    comptime if memoize:
        if frame.shared:
            memo[_key(frame.handle[])] = rebind[Memo](values.unsafe_get(len(values) - 1)).copy()
    if frame.owned:
        _ = owned.pop()


def _continue_with[F: Data, C: _ClauseSet, R: Value, rewrite: Bool](
    mut frame: _Frame[F], var target: Node[F], mut values: List[R], mut owned: List[Node[F]]
):
    """`Next`: the frame continues with a smaller value, which it owns; its partial results are released.

    An owned value is never looked up in or added to the memo: its address can
    be reused once it is released.
    """
    if target._cell[].height >= _node_of(frame, owned)[]._cell[].height:
        abort("fp.match: Next must continue with a smaller value")
    values.shrink(frame.base)
    if frame.owned:
        owned[len(owned) - 1] = target^
    else:
        owned.append(target^)
        frame.owned = True
    frame.shared = False
    _enter[F, C, R, rewrite](frame, owned)


def _call_candidate[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool, i: Int, t: Int, j: Int](
    frame: _Frame[F], mut values: List[R], owned: List[Node[F]], clauses: C, context: X
) raises E -> C.Sig[j].Out:
    """Call candidate `t`, clause `j`, with its argument; its evaluated fields are on the value stack."""
    comptime Stored = F.Layer[Node[F]].Case[i]
    comptime A = C.Sig[j].First
    comptime keep = _guarded[C, j]()
    var node = _node_of(frame, owned)
    ref stored = F.Layer[Node[F]].get[i](node[]._cell[].layer)
    comptime if A == Node[F]:
        comptime if not keep:
            values.shrink(frame.base)
        return _invoke[C, j, E](clauses, rebind[A](node[]), context)
    elif A == Stored and not _takes[F, C, R, rewrite, i, t]():
        comptime if not keep:
            values.shrink(frame.base)
        return _invoke[C, j, E](clauses, rebind[A](stored), context)
    else:
        var argument = _argument[F, C, R, rewrite, i, t, A, keep](rebind[Stored](stored), values, frame.base)
        return _invoke[C, j, E](clauses, rebind[A](argument), context)


def _invoke[C: _ClauseSet, j: Int, E: Value, X: AnyType](clauses: C, arg: C.Sig[j].First, context: X) raises E -> C.Sig[j].Out:
    """Call clause `j`, passing the context when the clause takes it."""
    comptime if C.Sig[j].arity == 2:
        return _call[C, j, E](clauses, arg, rebind[C.Sig[j].Second](context))
    else:
        return _call[C, j, E](clauses, arg)


@always_inline
def _steps[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool, i: Int](
    mut frame: _Frame[F], mut values: List[R], mut owned: List[Node[F]], clauses: C, context: X,
    mut child: Pointer[Node[F], ImmUntrackedOrigin]
) raises E -> Int:
    """Run the steps of a frame holding constructor `i` until it needs a child, completes or continues.

    Steps are numbered in the order they run, so after one step sets the next,
    the following checks in the same pass reach it.
    """
    comptime S = F.Layer[Node[F]]
    comptime Stored = S.Case[i]
    comptime In = reflect[Stored].field_types()
    comptime fields = reflect[Stored].field_count()
    comptime count = _candidates[F, C, rewrite, i]()
    var node = _node_of(frame, owned)
    ref stored = S.get[i](node[]._cell[].layer)
    while True:
        comptime for t in range(count):
            comptime for f in range(fields):
                comptime if _new_at[F, C, R, rewrite, i, t, f]():
                    if Int(frame.pc) == t * (fields + 1) + f:
                        comptime shape = _shape[F, In[f]]()
                        comptime then = _step_after[F, C, R, rewrite, i, t, f]()
                        comptime if shape == _ONE:
                            frame.pc = Int32(then)
                            child = Pointer(to=rebind[Node[F]](reflect[Stored].field_ref[f](stored))).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
                            return _CHILD
                        elif shape == _MANY:
                            ref items = rebind[List[Node[F]]](reflect[Stored].field_ref[f](stored))
                            if frame.sub < len(items):
                                child = Pointer(to=items.unsafe_get(frame.sub)).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
                                frame.sub += 1
                                return _CHILD
                            frame.sub = 0
                            frame.pc = Int32(then)
                        else:
                            frame.pc = Int32(then)
                            ref item = rebind[Optional[Node[F]]](reflect[Stored].field_ref[f](stored))
                            if item:
                                child = Pointer(to=item.unsafe_value()).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
                                return _CHILD
            if Int(frame.pc) == t * (fields + 1) + fields:
                comptime j = _candidate[F, C, rewrite, i, t]()
                comptime if j == C.count:
                    # Rewrite: no clause applied; rebuild from the rewritten children.
                    var rebuilt = _argument[F, C, R, rewrite, i, t, Stored, False](rebind[Stored](stored), values, frame.base)
                    if _unchanged[F, Stored](rebuilt, rebind[Stored](stored)):
                        var same = node[].copy()
                        values.append(rebind_var[R](same^))
                    else:
                        values.append(rebind_var[R](Node[F](rebind_var[downcast[Stored, Value]](rebuilt^))))
                    return _DONE
                else:
                    comptime O = C.Sig[j].Out
                    var out = _call_candidate[F, C, R, E, X, rewrite, i, t, j](frame, values, owned, clauses, context)
                    comptime if conforms_to(O, _Declinable):
                        var guarded = rebind_var[downcast[O, _Declinable]](out^)
                        if not guarded.accepted():
                            comptime if t + 1 < count:
                                frame.pc = Int32(_step_after[F, C, R, rewrite, i, t + 1, -1]())
                            else:
                                abort("fp.match: no clause applies")
                        else:
                            # The argument held copies; release the frame's results.
                            values.shrink(frame.base)
                            var inner = guarded^.take()
                            comptime if conforms_to(_Inner[O], _Continuation):
                                _continue_with[F, C, R, rewrite](frame, rebind_var[Next[Node[F]]](inner^).node, values, owned)
                                return _AGAIN
                            else:
                                values.append(rebind_var[R](inner^))
                                return _DONE
                    elif conforms_to(O, _Continuation):
                        _continue_with[F, C, R, rewrite](frame, rebind_var[Next[Node[F]]](out^).node, values, owned)
                        return _AGAIN
                    else:
                        values.append(rebind_var[R](out^))
                        return _DONE


@always_inline
def _advance[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool](
    mut frame: _Frame[F], mut values: List[R], mut owned: List[Node[F]], clauses: C, context: X,
    mut child: Pointer[Node[F], ImmUntrackedOrigin]
) raises E -> Int:
    """Step a frame until it needs a child or completes; `Next` may change its constructor."""
    comptime S = F.Layer[Node[F]]
    while True:
        var outcome = _AGAIN
        comptime for i in range(S.count):
            if Int(frame.ctor) == i:
                outcome = _steps[F, C, R, E, X, rewrite, i](frame, values, owned, clauses, context, child)
        if outcome != _AGAIN:
            return outcome


def _run[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool](root: Node[F], clauses: C, context: X) raises E -> R:
    """Match `root` with `clauses` in one loop; see the module docstring.

    The frame on top of the stack steps until it needs a child. The child is
    started and stepped at once: if it completes, as a leaf does, its result is
    on the value stack and the parent continues; otherwise it is pushed and the
    descent continues with the child it needs.
    """
    comptime memoize = conforms_to(R, Copyable)
    comptime Memo = downcast[R, Copyable & Deinitable] if memoize else Int
    var frames = List[_Frame[F]](capacity=32)
    var values = List[R](capacity=32)
    var owned = List[Node[F]]()
    var memo = Dict[Int, Memo]()
    var child = Pointer(to=root).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    while True:
        # Descend from `child` until a value completes in place.
        while True:
            var sub = _Frame[F](child)
            var outcome = _start[F, C, R, E, X, Memo, memoize, rewrite](sub, values, memo, owned, clauses, context, child)
            if outcome == _KNOWN:
                break
            if outcome == _DONE:
                _finish[F, R, Memo, memoize](sub, values, memo, owned)
                break
            frames.append(sub^)
        # Continue the frames above it until one needs another child.
        while True:
            if not frames:
                return values.pop()
            if _advance[F, C, R, E, X, rewrite](frames.unsafe_get(len(frames) - 1), values, owned, clauses, context, child) == _CHILD:
                break
            var frame = frames.pop()
            _finish[F, R, Memo, memoize](frame, values, memo, owned)
