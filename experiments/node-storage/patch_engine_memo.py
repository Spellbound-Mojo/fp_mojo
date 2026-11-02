"""Overlay patch, applied after `patch_cells.py` and `patch_engine_setup.py`: a short memo list.

A match whose value shares a sub-value remembers that sub-value's result. The
loop made a `Dict` for it on the first shared value; here the first 16 results
go in one list searched linearly, and only a match with more shared values
moves them into a `Dict`.

Parts: `memo` (the only part).
"""


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_engine_memo: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


MEMO = '''

comptime _SHORT_MEMO = 16
"""How many shared results are searched linearly before they move to a Dict."""


struct _Memo[V: Copyable & Deinitable](Movable):
    """Results of the shared values matched so far, by cell address."""

    var _short: List[Tuple[Int, Self.V]]
    var _table: Optional[Dict[Int, Self.V]]

    def __init__(out self):
        self._short = List[Tuple[Int, Self.V]]()
        self._table = None

    def get(self, key: Int) -> Optional[Self.V]:
        if self._table:
            return self._table.value().get(key)
        for i in range(len(self._short)):
            if self._short.unsafe_get(i)[0] == key:
                return Optional(self._short.unsafe_get(i)[1].copy())
        return None

    def put(mut self, key: Int, var value: Self.V):
        if self._table:
            self._table.value()[key] = value^
            return
        if len(self._short) < _SHORT_MEMO:
            if not self._short:
                self._short.reserve(_SHORT_MEMO)
            self._short.append((key, value^))
            return
        var table = Dict[Int, Self.V]()
        for i in range(len(self._short)):
            table[self._short.unsafe_get(i)[0]] = self._short.unsafe_get(i)[1].copy()
        table[key] = value^
        self._table = table^
        self._short.clear()
'''


def patch(folder, parts=None):
    engine = folder / 'fp' / 'matching' / '_engine.mojo'
    s = engine.read_text()
    if 'var memo = Optional[Dict[Int, Memo]]()' not in s:
        raise SystemExit('patch_engine_memo: apply patch_engine_setup.py first')
    anchor = '\n\ntrait _Signature:'
    s = sub(s, anchor, MEMO + anchor, where='memo definition')
    s = sub(s, 'memo: Optional[Dict[Int, Memo]], mut owned: List[Node[F]], clauses: C, context: X,',
            'memo: _Memo[Memo], mut owned: List[Node[F]], clauses: C, context: X,', where='start signature')
    s = sub(s, '''            if memo:
                var known = memo.value().get(_key(frame.handle[]))
                if known:
                    values.append(rebind_var[R](known.take()))
                    return _KNOWN''', '''            var known = memo.get(_key(frame.handle[]))
            if known:
                values.append(rebind_var[R](known.take()))
                return _KNOWN''', where='start lookup')
    s = sub(s, 'mut memo: Optional[Dict[Int, Memo]], mut owned: List[Node[F]]',
            'mut memo: _Memo[Memo], mut owned: List[Node[F]]', where='finish signature')
    s = sub(s, '''            if not memo:
                memo = Dict[Int, Memo]()
            memo.value()[_key(frame.handle[])] = rebind[Memo](values.unsafe_get(len(values) - 1)).copy()''',
            '''            memo.put(_key(frame.handle[]), rebind[Memo](values.unsafe_get(len(values) - 1)).copy())''',
            where='finish insert')
    s = sub(s, 'var memo = Optional[Dict[Int, Memo]]()', 'var memo = _Memo[Memo]()', where='run setup')
    engine.write_text(s)
