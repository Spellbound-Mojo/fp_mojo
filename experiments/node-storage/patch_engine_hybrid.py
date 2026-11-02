"""Overlay patch, applied after `patch_cells.py` and `patch_engine_setup.py`: bounded native recursion.

The matching loop kept every pending value in a frame on its own stack. Here a
value is evaluated by native recursion, its frame a local, while it is fewer
than `_NATIVE_DEPTH` levels below the subject; deeper values continue on the
explicit stack as before, so native stack use stays bounded by a constant.
Both paths run the same steps (`_start`, `_advance`, `_finish`) in the same
order, so results, memoization, `Next`, errors and evaluation order are
unchanged.

Parts: `hybrid` (the only part).
"""


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_engine_hybrid: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


RUN_OLD_START = 'def _run[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool](root: Node[F], clauses: C, context: X) raises E -> R:'

RUN_NEW = '''comptime _NATIVE_DEPTH = 64
"""How many levels below the subject are evaluated by native recursion."""


def _descend[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool, rewrite: Bool](
    value: Pointer[Node[F], ImmUntrackedOrigin], depth: Int, mut values: List[R], mut memo: Optional[Dict[Int, Memo]],
    mut owned: List[Node[F]], mut frames: List[_Frame[F]], clauses: C, context: X
) raises E:
    """Evaluate `value`, leaving its result on the value stack: by native
    recursion above `_NATIVE_DEPTH`, then on the explicit stack."""
    if depth >= _NATIVE_DEPTH:
        _drive[F, C, R, E, X, Memo, memoize, rewrite](value, values, memo, owned, frames, clauses, context)
        return
    var child = value
    var frame = _Frame[F](value)
    var outcome = _start[F, C, R, E, X, Memo, memoize, rewrite](frame, values, memo, owned, clauses, context, child)
    if outcome == _KNOWN:
        return
    while outcome == _CHILD:
        _descend[F, C, R, E, X, Memo, memoize, rewrite](child, depth + 1, values, memo, owned, frames, clauses, context)
        outcome = _advance[F, C, R, E, X, rewrite](frame, values, owned, clauses, context, child)
    _finish[F, R, Memo, memoize](frame, values, memo, owned)


def _drive[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, Memo: Copyable & Deinitable, memoize: Bool, rewrite: Bool](
    value: Pointer[Node[F], ImmUntrackedOrigin], mut values: List[R], mut memo: Optional[Dict[Int, Memo]],
    mut owned: List[Node[F]], mut frames: List[_Frame[F]], clauses: C, context: X
) raises E:
    """Evaluate `value` on the explicit stack, leaving its result on the value stack.

    The frame on top of the stack steps until it needs a child. The child is
    started and stepped at once: if it completes, as a leaf does, its result is
    on the value stack and the parent continues; otherwise it is pushed and the
    descent continues with the child it needs.
    """
    var base = len(frames)
    var child = value
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
            if not frames:
                frames.reserve(32)
            frames.append(sub^)
        # Continue the frames above it until one needs another child.
        while True:
            if len(frames) == base:
                return
            if _advance[F, C, R, E, X, rewrite](frames.unsafe_get(len(frames) - 1), values, owned, clauses, context, child) == _CHILD:
                break
            var frame = frames.pop()
            _finish[F, R, Memo, memoize](frame, values, memo, owned)


def _run[F: Data, C: _ClauseSet, R: Value, E: Value, X: AnyType, rewrite: Bool](root: Node[F], clauses: C, context: X) raises E -> R:
    """Match `root` with `clauses`: native recursion near the subject, an explicit stack below."""
    comptime memoize = conforms_to(R, Copyable)
    comptime Memo = downcast[R, Copyable & Deinitable] if memoize else Int
    var frames = List[_Frame[F]]()
    var values = List[R](capacity=32)
    var owned = List[Node[F]]()
    var memo = Optional[Dict[Int, Memo]]()
    _descend[F, C, R, E, X, Memo, memoize, rewrite](
        Pointer(to=root).as_imm().unsafe_origin_cast[ImmUntrackedOrigin](), 0, values, memo, owned, frames, clauses, context)
    return values.pop()
'''


def patch(folder, parts=None):
    engine = folder / 'fp' / 'matching' / '_engine.mojo'
    s = engine.read_text()
    if 'var memo = Optional[Dict[Int, Memo]]()' not in s:
        raise SystemExit('patch_engine_hybrid: apply patch_engine_setup.py first')
    start = s.index(RUN_OLD_START)
    if s.find('\ndef ', start + 1) != -1 or s.find('\nstruct ', start + 1) != -1:
        raise SystemExit('patch_engine_hybrid: _run is expected to be the last definition in _engine.mojo')
    s = s[:start] + RUN_NEW
    engine.write_text(s)
