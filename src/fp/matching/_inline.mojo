"""Matching without recursion: one value that is not a `Node`, or several values together.

A subject is one of:

- a `Node`: a clause parameter is one of its constructors as stored, or the
  whole `Node` type;
- a value stored in place (`Choice`, `Result`, `ControlFlow`): a constructor of
  its data type, or the whole type;
- an `Optional[T]`: `T` for a present value, `NoneType` for an absent one, or
  the whole `Optional[T]`;
- any other value: its own type.

A context is passed as it is. The clauses are tried in order and the first whose
parameters all apply, and whose guard holds, is called. Nothing recurses, so the
clause arguments are references into the subjects.
"""
from std.builtin.rebind import rebind_var, downcast
from std.os import abort
from fp.adt.data import Value, Data, Node, _NodeType, _ChoiceType, _layer
from fp.matching.clauses import _Continuation, _Declinable
from fp.matching._engine import _ClauseSet, _Absent, _Inner, _call, _name, _guarded, _first_constructor
from fp._internal.errors import _ErrorCompatible


struct _Context[X: AnyType](ImplicitlyCopyable, _ContextType):
    """A context among the subjects: passed to the clauses as it is, never matched."""

    comptime Of: AnyType = Self.X
    var value: Pointer[Self.X, ImmUntrackedOrigin]

    def __init__(out self, ref value: Self.X):
        self.value = Pointer(to=value).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()


trait _ContextType:
    comptime Of: AnyType


# ----------------------------------------------------------------- subject kinds

comptime _PLAIN = 0
comptime _NODE = 1
comptime _CHOICE = 2
comptime _OPTIONAL = 3
comptime _CONTEXT = 4

comptime _ANY = -1     # A parameter that takes every case.
comptime _NONE = -2    # A parameter that takes no case of the subject.


def _is_optional[S: AnyType]() -> Bool:
    # A generic function cannot name `Optional`'s element type, so the type is
    # recognized by name; the element type comes from the clause that takes it.
    return reflect[S].name().startswith("std.collections.optional.Optional[")


def _kind[S: AnyType]() -> Int:
    comptime if conforms_to(S, _NodeType):
        return _NODE
    elif conforms_to(S, _ChoiceType):
        return _CHOICE
    elif conforms_to(S, _ContextType):
        return _CONTEXT
    elif _is_optional[S]():
        return _OPTIONAL
    return _PLAIN


def _cases[S: AnyType]() -> Int:
    """How many cases a subject of type `S` distinguishes."""
    comptime kind = _kind[S]()
    comptime if kind == _NODE:
        comptime F = downcast[S, _NodeType].Of
        return F.Layer[Node[F]].count
    elif kind == _CHOICE:
        comptime F = downcast[S, _ChoiceType].Of
        return F.Layer[Node[F]].count
    elif kind == _OPTIONAL:
        return 2
    return 1


def _selects[S: AnyType, A: AnyType]() -> Int:
    """The case a parameter of type `A` takes in a subject of type `S`: an index, `_ANY` or `_NONE`."""
    comptime kind = _kind[S]()
    comptime if kind == _NODE:
        comptime F = downcast[S, _NodeType].Of
        comptime if A == Node[F]:
            return _ANY
        comptime k = _first_constructor[F, A]()
        comptime if k >= 0 and A == F.Layer[Node[F]].Case[k]:
            return k
        return _NONE
    elif kind == _CHOICE:
        comptime F = downcast[S, _ChoiceType].Of
        comptime if A == S:
            return _ANY
        comptime k = _first_constructor[F, A]()
        comptime if k >= 0 and A == F.Layer[Node[F]].Case[k]:
            return k
        return _NONE
    elif kind == _OPTIONAL:
        comptime if A == S:
            return _ANY
        elif A == NoneType:
            return 1
        elif S == Optional[A]:
            return 0
        return _NONE
    elif kind == _CONTEXT:
        comptime if A == downcast[S, _ContextType].Of:
            return _ANY
        return _NONE
    comptime if A == S:
        return _ANY
    return _NONE


def _accepts[S: AnyType, A: AnyType]() -> Bool:
    """Whether `A` is a parameter type for a subject of type `S`."""
    comptime if _kind[S]() == _OPTIONAL:
        comptime if S == Optional[NoneType]:
            return False
    return _selects[S, A]() != _NONE


def _expected[S: AnyType]() -> String:
    """The parameter types a subject of type `S` accepts, for a diagnostic."""
    comptime kind = _kind[S]()
    comptime if kind == _NODE:
        return "a constructor as stored, or the whole Node type"
    elif kind == _CHOICE:
        return "a constructor of its data type, or its whole type"
    elif kind == _OPTIONAL:
        return "the type of a present value, NoneType for an absent one, or the whole Optional"
    elif kind == _CONTEXT:
        return "the context's type"
    return "the subject's type"


def _hits[S: AnyType, A: AnyType, index: Int]() -> Bool:
    """Whether a parameter of type `A` applies to case `index` of a subject of type `S`."""
    comptime k = _selects[S, A]()
    return k == _ANY or k == index


def _applies[S: AnyType, A: AnyType](subject: S) -> Bool:
    comptime k = _selects[S, A]()
    comptime kind = _kind[S]()
    comptime if k == _ANY:
        return True
    elif kind == _NODE:
        comptime F = downcast[S, _NodeType].Of
        return F.Layer[Node[F]].is_case[k](rebind[Node[F]](subject)._cell[].layer)
    elif kind == _CHOICE:
        comptime F = downcast[S, _ChoiceType].Of
        return F.Layer[Node[F]].is_case[k](_layer[F](subject))
    else:
        var present = Bool(rebind[downcast[S, Boolable]](subject))
        return present if k == 0 else not present


def _view[S: AnyType, A: AnyType](subject: S, none: Pointer[NoneType, ImmUntrackedOrigin]) -> Pointer[A, ImmUntrackedOrigin]:
    """The clause argument for one subject: a stored constructor or value, or the subject itself."""
    comptime k = _selects[S, A]()
    comptime kind = _kind[S]()
    comptime if kind == _CONTEXT:
        return rebind[Pointer[A, ImmUntrackedOrigin]](rebind[_Context[A]](subject).value)
    elif k == _ANY:
        return Pointer(to=rebind[A](subject)).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    elif kind == _NODE:
        comptime F = downcast[S, _NodeType].Of
        ref stored = F.Layer[Node[F]].get[k](rebind[Node[F]](subject)._cell[].layer)
        return Pointer(to=rebind[A](stored)).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    elif kind == _CHOICE:
        comptime F = downcast[S, _ChoiceType].Of
        ref stored = F.Layer[Node[F]].get[k](_layer[F](subject))
        return Pointer(to=rebind[A](stored)).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    elif k == 0:
        ref present = rebind[Optional[A]](subject).unsafe_value()
        return Pointer(to=present).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    else:
        return rebind[Pointer[A, ImmUntrackedOrigin]](none)


def _case_name[S: AnyType, index: Int]() -> String:
    comptime kind = _kind[S]()
    comptime if kind == _NODE:
        comptime F = downcast[S, _NodeType].Of
        return String(reflect[F.Layer[Node[F]].Case[index]].base_name())
    elif kind == _CHOICE:
        comptime F = downcast[S, _ChoiceType].Of
        return String(reflect[F.Layer[Node[F]].Case[index]].base_name())
    elif kind == _OPTIONAL:
        return "a present value" if index == 0 else "None"
    return _name[S]()


def _single_case_name[S: AnyType, index: Int]() -> String:
    """A case of a single subject, for a diagnostic."""
    comptime kind = _kind[S]()
    comptime if kind == _NODE or kind == _CHOICE:
        return "constructor " + _case_name[S, index]()
    elif kind == _OPTIONAL:
        return _case_name[S, index]()
    return "the subject"


# ----------------------------------------------------------------- admission

def _subjects[S1: AnyType, S2: AnyType]() -> Int:
    """How many subjects are matched: the first, and the others that are not a context or absent."""
    var count = 1
    comptime if not (S1 == _Absent) and _kind[S1]() != _CONTEXT:
        count += 1
    comptime if not (S2 == _Absent) and _kind[S2]() != _CONTEXT:
        count += 1
    return count


def _position[S: AnyType, p: Int, count: Int]() -> String:
    """Which subject parameter `p` belongs to, for a diagnostic."""
    comptime if _kind[S]() == _CONTEXT:
        return "the context, of type " + _name[downcast[S, _ContextType].Of]()
    elif count == 1:
        return "the subject, of type " + _name[S]()
    return ("the first" if p == 0 else "the second" if p == 1 else "the third") + " subject, of type " + _name[S]()


def _covers[C: _ClauseSet, S0: AnyType, S1: AnyType, S2: AnyType, j: Int, i0: Int, i1: Int, i2: Int]() -> Bool:
    comptime T = C.Sig[j]
    return _hits[S0, T.First, i0]() and _hits[S1, T.Second, i1]() and _hits[S2, T.Third, i2]()


def _settled[C: _ClauseSet, S0: AnyType, S1: AnyType, S2: AnyType, before: Int, i0: Int, i1: Int, i2: Int]() -> Bool:
    """Whether a clause before `before` that cannot decline covers the combination."""
    comptime for j in range(before):
        comptime if not _guarded[C, j]() and _covers[C, S0, S1, S2, j, i0, i1, i2]():
            return True
    return False


def _reachable[C: _ClauseSet, S0: AnyType, S1: AnyType, S2: AnyType, j: Int]() -> Bool:
    comptime for i0 in range(_cases[S0]()):
        comptime for i1 in range(_cases[S1]()):
            comptime for i2 in range(_cases[S2]()):
                comptime if _covers[C, S0, S1, S2, j, i0, i1, i2]() and not _settled[C, S0, S1, S2, j, i0, i1, i2]():
                    return True
    return False


def _uncovered[S0: AnyType, S1: AnyType, S2: AnyType, i0: Int, i1: Int, i2: Int]() -> String:
    """The diagnostic for a combination of cases that no clause covers."""
    comptime if _subjects[S1, S2]() == 1:
        return "fp.match: " + _single_case_name[S0, i0]() + " has no clause that cannot decline"
    var names = _case_name[S0, i0]()
    comptime if _kind[S1]() != _CONTEXT:
        names += ", " + _case_name[S1, i1]()
    comptime if not (S2 == _Absent) and _kind[S2]() != _CONTEXT:
        names += ", " + _case_name[S2, i2]()
    return "fp.match: no clause that cannot decline covers (" + names + ")"


def _accepted[C: _ClauseSet, S0: AnyType, S1: AnyType, S2: AnyType, j: Int]() -> Bool:
    comptime T = C.Sig[j]
    return _accepts[S0, T.First]() and _accepts[S1, T.Second]() and _accepts[S2, T.Third]()


def _all_accepted[C: _ClauseSet, S0: AnyType, S1: AnyType, S2: AnyType]() -> Bool:
    comptime for j in range(C.count):
        comptime if not _accepted[C, S0, S1, S2, j]():
            return False
    return True


def _admit_inline[C: _ClauseSet, R: Value, E: Value, S0: AnyType, S1: AnyType, S2: AnyType]() -> Bool:
    """The compile-time rules of a match without recursion; each failure names the clause or case.

    The compiler reports the last constraint that fails, so a rule that depends
    on an earlier one is checked only once the earlier one holds.
    """
    comptime count = _subjects[S1, S2]()
    # The result type is `_NoResult` only when every clause returns `Next`,
    # which the rule for `Next` below reports.
    comptime for j in range(C.count):
        comptime T = C.Sig[j]
        comptime assert _accepts[S0, T.First](), (
            "fp.match: clause " + String(j) + " takes " + _name[T.First]() + " for " + _position[S0, 0, count]()
            + "; it takes " + _expected[S0]())
        comptime if _kind[S1]() == _CONTEXT:
            comptime assert _accepts[S1, T.Second](), (
                "fp.match: clause " + String(j) + " takes " + _name[T.Second]() + " as its second parameter; the context is "
                + _name[downcast[S1, _ContextType].Of]())
        else:
            comptime assert _accepts[S1, T.Second](), (
                "fp.match: clause " + String(j) + " takes " + _name[T.Second]() + " for " + _position[S1, 1, count]()
                + "; it takes " + _expected[S1]())
        comptime assert _accepts[S2, T.Third](), (
            "fp.match: clause " + String(j) + " takes " + _name[T.Third]() + " for " + _position[S2, 2, count]()
            + "; it takes " + _expected[S2]())
        comptime if _accepted[C, S0, S1, S2, j]():
            comptime V = _Inner[T.Out]
            comptime assert not conforms_to(V, _Continuation), (
                "fp.match: clause " + String(j) + " returns Next; Next continues with a smaller Node, "
                + ("and the subject is not a Node" if count == 1 else "and is not available with several subjects"))
            comptime assert V == R or conforms_to(V, _Continuation), (
                "fp.match: clause " + String(j) + " returns " + _name[V]() + "; every clause returns " + _name[R]())
            comptime assert _ErrorCompatible[E, T.Err], (
                "fp.match: clause " + String(j) + " raises a different error type from an earlier clause; every clause raises one error type or none")
            comptime if _all_accepted[C, S0, S1, S2]():
                comptime assert _reachable[C, S0, S1, S2, j](), (
                    "fp.match: clause " + String(j) + " is never selected: earlier clauses that cannot decline cover every case it applies to")
    comptime if _all_accepted[C, S0, S1, S2]():
        comptime for i0 in range(_cases[S0]()):
            comptime for i1 in range(_cases[S1]()):
                comptime for i2 in range(_cases[S2]()):
                    comptime assert _settled[C, S0, S1, S2, C.count, i0, i1, i2](), _uncovered[S0, S1, S2, i0, i1, i2]()
    return True


# ----------------------------------------------------------------- running

def _call_on[C: _ClauseSet, j: Int, E: Value, S0: AnyType, S1: AnyType, S2: AnyType](
    clauses: C, a: S0, b: S1, c: S2
) raises E -> C.Sig[j].Out:
    """Call clause `j` with its view of each subject."""
    comptime T = C.Sig[j]
    var none = NoneType()
    var absent = Pointer(to=none).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()
    comptime if T.arity == 1:
        return _call[C, j, E](clauses, _view[S0, T.First](a, absent)[])
    elif T.arity == 2:
        return _call[C, j, E](clauses, _view[S0, T.First](a, absent)[], _view[S1, T.Second](b, absent)[])
    else:
        return _call[C, j, E](
            clauses, _view[S0, T.First](a, absent)[], _view[S1, T.Second](b, absent)[], _view[S2, T.Third](c, absent)[])


def _run_inline[C: _ClauseSet, R: Value, E: Value, S0: AnyType, S1: AnyType, S2: AnyType](
    a: S0, b: S1, c: S2, clauses: C
) raises E -> R:
    """Call the first clause that applies to every subject and does not decline."""
    comptime for j in range(C.count):
        comptime T = C.Sig[j]
        if _applies[S0, T.First](a) and _applies[S1, T.Second](b) and _applies[S2, T.Third](c):
            var out = _call_on[C, j, E](clauses, a, b, c)
            comptime if conforms_to(T.Out, _Declinable):
                var guarded = rebind_var[downcast[T.Out, _Declinable]](out^)
                if guarded.accepted():
                    return rebind_var[R](guarded^.take())
            else:
                return rebind_var[R](out^)
    abort("fp.match: no clause applies")
