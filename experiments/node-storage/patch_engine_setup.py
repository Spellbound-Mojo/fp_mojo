"""Overlay patch, applied after `patch_cells.py`: per-call setup of the matching loop.

The loop pre-sized its frame and value stacks to 32 entries and made its memo
table on every call. Here the frame stack reserves its 32 entries at its first
push, which a value that completes in one step (a leaf) never makes, and the
memo table is made when the first shared value completes. The value stack keeps
its 32 entries: every match pushes a result, and growing it from empty cost
more than the one allocation (measured: a two-leaf match went from about 140 to
about 190-230 ns per call).

Parts: `setup` (the only part).
"""


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_engine_setup: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


def patch(folder, parts=None):
    engine = folder / 'fp' / 'matching' / '_engine.mojo'
    s = engine.read_text()
    s = sub(s, '    mut frame: _Frame[F], mut values: List[R], memo: Dict[Int, Memo], mut owned: List[Node[F]], clauses: C, context: X,',
            '    mut frame: _Frame[F], mut values: List[R], memo: Optional[Dict[Int, Memo]], mut owned: List[Node[F]], clauses: C, context: X,',
            where='start signature')
    s = sub(s, '''        if frame.handle[]._shared():
            var known = memo.get(_key(frame.handle[]))
            if known:
                values.append(rebind_var[R](known.take()))
                return _KNOWN
            frame.shared = True''', '''        if frame.handle[]._shared():
            if memo:
                var known = memo.value().get(_key(frame.handle[]))
                if known:
                    values.append(rebind_var[R](known.take()))
                    return _KNOWN
            frame.shared = True''', where='start lookup')
    s = sub(s, '    frame: _Frame[F], values: List[R], mut memo: Dict[Int, Memo], mut owned: List[Node[F]]',
            '    frame: _Frame[F], values: List[R], mut memo: Optional[Dict[Int, Memo]], mut owned: List[Node[F]]',
            where='finish signature')
    s = sub(s, '''        if frame.shared:
            memo[_key(frame.handle[])] = rebind[Memo](values.unsafe_get(len(values) - 1)).copy()''', '''        if frame.shared:
            if not memo:
                memo = Dict[Int, Memo]()
            memo.value()[_key(frame.handle[])] = rebind[Memo](values.unsafe_get(len(values) - 1)).copy()''',
            where='finish insert')
    s = sub(s, '''    var frames = List[_Frame[F]](capacity=32)
    var values = List[R](capacity=32)
    var owned = List[Node[F]]()
    var memo = Dict[Int, Memo]()''', '''    var frames = List[_Frame[F]]()
    var values = List[R](capacity=32)
    var owned = List[Node[F]]()
    var memo = Optional[Dict[Int, Memo]]()''', where='run setup')
    s = sub(s, '''            frames.append(sub^)''', '''            if not frames:
                frames.reserve(32)
            frames.append(sub^)''', where='run first frame')
    engine.write_text(s)
