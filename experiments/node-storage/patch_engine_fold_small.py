"""Overlay patch on current src: evaluate small values with static match plans by recursion.

A plan is static when, for every constructor, the first applicable clause can
neither decline (no guard) nor continue with `Next`. A match of a subject at
most `_FOLD_DEPTH` (8) levels high with a static plan runs `_fold`: dispatch on
the value's constructor, evaluate the fields its clause takes evaluated by
direct recursion in field order, build the argument and call the clause, with
the same memo table semantics. Every other match, including every subject
taller than 8 levels, runs the explicit-stack loop (`_drive`, the former
`_run`) unchanged, so native recursion is at most 8 levels deep.

Measured on 100,000 calls: a one-leaf match about 9x faster, a two-leaf match
about 1.5x, a seven-node match about 1.15x; large matches unchanged. Folding
every static plan (`patch_engine_fold.py`) did not speed up large matches: the
recursive fold calls clauses through pointers, where the loop is inlined into
the caller and calls them directly. If a clause raises while an argument is
being built, the fields already evaluated into it are destroyed first.

Parts: `fold` (the only part).
"""


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_engine_fold: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


FOLD = '''

# ----------------------------------------------------------------- static plans

comptime _FOLD_DEPTH = 8
"""How many levels below the subject a static plan is evaluated by recursion."""


def _static[F: Data, C: _ClauseSet, R: Value, rewrite: Bool]() -> Bool:
    """Whether each constructor's first applicable clause decides it: no guard, no `Next`."""
    comptime if rewrite:
        return False
    comptime S = F.Layer[Node[F]]
    comptime for i in range(S.count):
        comptime if _candidates[F, C, False, i]() != 1:
            return False
        comptime j = _candidate[F, C, False, i, 0]()
        comptime if j < 0 or _guarded[C, j]() or conforms_to(C.Sig[j].Out, _Continuation):
            return False
    return True


def _fold[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool](
    node: Node[F], depth: Int, mut memo: Dict[Int, Memo], clauses: C, context: X
) raises E -> R:
    """The result of matching `node` with a static plan; see `_static`."""
    comptime S = F.Layer[Node[F]]
    comptime if memoize:
        if node._shared():
            var known = memo.get(node._address())
            if known:
                return rebind_var[R](known.take())
    var tag = node._tag()
    comptime for i in range(S.count):
        if tag == i:
            var result = _fold_case[F, C, R, E, X, Memo, memoize, i](node, depth, memo, clauses, context)
            comptime if memoize:
                if node._shared():
                    memo[node._address()] = rebind[Memo](result).copy()
            return result^
    abort("fp.match: no active constructor")


@always_inline
def _fold_child[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool](
    child: Node[F], depth: Int, mut memo: Dict[Int, Memo], clauses: C, context: X
) raises E -> R:
    """A child's result: it is lower than the folded subject, so it is folded too."""
    return _fold[F, C, R, E, X, Memo, memoize](child, depth, memo, clauses, context)


@always_inline
def _fold_case[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool, i: Int](
    node: Node[F], depth: Int, mut memo: Dict[Int, Memo], clauses: C, context: X
) raises E -> R:
    comptime Stored = F.Layer[Node[F]].Case[i]
    comptime j = _candidate[F, C, False, i, 0]()
    comptime A = C.Sig[j].First
    comptime if A == Node[F]:
        return rebind_var[R](_invoke[C, j, E](clauses, rebind[A](node), context))
    elif A == Stored and not _takes[F, C, R, False, i, 0]():
        return rebind_var[R](_invoke[C, j, E](clauses, rebind[A](node._get[i]()), context))
    else:
        var argument = _fold_argument[F, C, R, E, X, Memo, memoize, i, A](node._get[i](), depth, memo, clauses, context)
        return rebind_var[R](_invoke[C, j, E](clauses, rebind[A](argument), context))


def _drop_folded[F: Data, C: _ClauseSet, R: Value, i: Int, A: AnyType, upto: Int](memory: Pointer[UInt8, MutUntrackedOrigin]):
    """Destroy the evaluated fields before field `upto` written into an argument."""
    comptime Stored = F.Layer[Node[F]].Case[i]
    comptime Want = reflect[A].field_types()
    comptime for g in range(upto):
        comptime if _folds[F, C, R, False, i, 0, g]():
            memory.unsafe_offset(reflect[A].field_offset[index=g]()).unsafe_bitcast[downcast[Want[g], Movable & Deinitable]]().unsafe_deinit_pointee()


@always_inline
def _fold_argument[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool, i: Int, A: AnyType](
    value: F.Layer[Node[F]].Case[i], depth: Int, mut memo: Dict[Int, Memo], clauses: C, context: X
) raises E -> downcast[A, Value]:
    """The clause argument: evaluated fields first, in field order, then the others copied."""
    comptime Stored = F.Layer[Node[F]].Case[i]
    comptime In = reflect[Stored].field_types()
    comptime Want = reflect[A].field_types()
    comptime fields = reflect[Stored].field_count()
    comptime assert conforms_to(A, Value), "fp.match: a clause parameter that evaluates fields must be Movable"
    var slot = MaybeUninit[downcast[A, Value]]()
    var memory = slot.unsafe_ptr().unsafe_bitcast[UInt8]().unsafe_origin_cast[MutUntrackedOrigin]()
    comptime for f in range(fields):
        comptime if _folds[F, C, R, False, i, 0, f]():
            comptime T = downcast[Want[f], Movable]
            comptime shape = _shape[F, In[f]]()
            var target = memory.unsafe_offset(reflect[A].field_offset[index=f]()).unsafe_bitcast[T]()
            try:
                comptime if shape == _ONE:
                    var result = _fold_child[F, C, R, E, X, Memo, memoize](
                        rebind[Node[F]](reflect[Stored].field_ref[f](value)), depth + 1, memo, clauses, context)
                    target.unsafe_write(rebind_var[T](result^))
                elif shape == _MANY:
                    ref items = rebind[List[Node[F]]](reflect[Stored].field_ref[f](value))
                    var results = List[R](capacity=len(items))
                    for item in items:
                        results.append(_fold_child[F, C, R, E, X, Memo, memoize](item, depth + 1, memo, clauses, context))
                    target.unsafe_write(rebind_var[T](results^))
                else:
                    ref item = rebind[Optional[Node[F]]](reflect[Stored].field_ref[f](value))
                    var result = Optional[R]()
                    if item:
                        result = Optional[R](_fold_child[F, C, R, E, X, Memo, memoize](item.value(), depth + 1, memo, clauses, context))
                    target.unsafe_write(rebind_var[T](result^))
            except error:
                _drop_folded[F, C, R, i, A, f](memory)
                slot^.unsafe_forget()
                _propagate_error[E](error^)
    comptime for f in range(fields):
        comptime if not _folds[F, C, R, False, i, 0, f]():
            comptime T = downcast[Want[f], Movable]
            comptime assert conforms_to(In[f], Copyable), (
                "fp.match: field " + String(reflect[Stored].field_names()[f]) + " of " + reflect[Stored].base_name()
                + " is copied into the clause argument and must be Copyable")
            var target = memory.unsafe_offset(reflect[A].field_offset[index=f]()).unsafe_bitcast[T]()
            target.unsafe_write(rebind_var[T](rebind[downcast[In[f], Copyable]](reflect[Stored].field_ref[f](value)).copy()))
    return slot^.unsafe_assume_init()


def _run[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool](root: Node[F], clauses: C, context: X) raises E -> R:
    """Match `root` with `clauses`: a static plan by `_fold`, any other by `_drive`."""
    comptime memoize = conforms_to(R, Copyable)
    comptime Memo = downcast[R, Copyable & Deinitable] if memoize else Int
    var memo = Dict[Int, Memo]()
    comptime if _static[F, C, R, rewrite]():
        if root._height() <= _FOLD_DEPTH:
            return _fold[F, C, R, E, X, Memo, memoize](root, 0, memo, clauses, context)
    return _drive[F, C, R, E, X, Memo, memoize, rewrite](root, memo, clauses, context)
'''


def patch(folder, parts=None):
    engine = folder / 'fp' / 'matching' / '_engine.mojo'
    s = engine.read_text()
    s = sub(s, 'from fp._internal.errors import _ErrorCompatible, _forward\n',
            'from fp._internal.errors import _ErrorCompatible, _forward, _propagate_error\n', where='imports')
    s = sub(s, 'def _run[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool](root: Node[F], clauses: C, context: X) raises E -> R:\n    """Match `root` with `clauses` in one loop; see the module docstring.',
            'def _drive[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool, rewrite: Bool](\n'
            '    root: Node[F], mut memo: Dict[Int, Memo], clauses: C, context: X\n'
            ') raises E -> R:\n    """Match `root` with `clauses` in one loop, recording shared results in `memo`; see the module docstring.',
            where='drive signature')
    s = sub(s, '''    comptime memoize = conforms_to(R, Copyable)
    comptime Memo = downcast[R, Copyable & Deinitable] if memoize else Int
    var frames = List[_Frame[F]](capacity=32)
    var values = List[R](capacity=32)
    var owned = List[Node[F]]()
    var memo = Dict[Int, Memo]()''', '''    var frames = List[_Frame[F]](capacity=32)
    var values = List[R](capacity=32)
    var owned = List[Node[F]]()''', where='drive setup')
    if s.find('\ndef ', s.index('def _drive[')) != -1 or s.find('\nstruct ', s.index('def _drive[')) != -1:
        raise SystemExit('patch_engine_fold: _run is expected to be the last definition in _engine.mojo')
    s = s.rstrip('\n') + '\n' + FOLD
    engine.write_text(s)
