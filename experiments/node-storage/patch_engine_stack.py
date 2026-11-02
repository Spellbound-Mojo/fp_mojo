"""Overlay patch, applied after `patch_cells.py` and `patch_engine_setup.py`: unchecked loop stacks.

The matching loop keeps pending frames and evaluated results on `List`s; their
pushes and pops are bounds-checked, and a profile of `fp.match` over a large
tree attributes about 26 of roughly 66 instructions per value to `List` and its
checks. Here both stacks are a minimal owned buffer whose `pop` and indexing are
unchecked: the loop's own plan guarantees every pop matches an earlier push.

Parts: `stack` (the only part).
"""


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_engine_stack: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


STACK = '''

struct _Stack[T: Movable & Deinitable](Movable, Sized):
    """The matching loop's stack of frames or results: unchecked pushes and pops.

    Every pop and index is within the pushed elements by construction of the
    loop's plan, so neither is checked; growth is.
    """

    var _data: Pointer[Self.T, MutUntrackedOrigin]
    var _len: Int
    var _cap: Int

    def __init__(out self, capacity: Int):
        self._len = 0
        self._cap = capacity
        if capacity > 0:
            self._data = unsafe_alloc[Self.T](capacity)
        else:
            self._data = Pointer[Self.T, MutUntrackedOrigin].unsafe_dangling()

    def __deinit__(deinit self):
        for i in range(self._len):
            self._data.unsafe_offset(i).unsafe_deinit_pointee()
        if self._cap > 0:
            self._data.unsafe_free()

    @always_inline
    def __len__(self) -> Int:
        return self._len

    @always_inline
    def __bool__(self) -> Bool:
        return self._len != 0

    @no_inline
    def _grow(mut self, capacity: Int):
        var data = unsafe_alloc[Self.T](capacity)
        for i in range(self._len):
            data.unsafe_offset(i).unsafe_write(self._data.unsafe_offset(i).unsafe_take_pointee())
        if self._cap > 0:
            self._data.unsafe_free()
        self._data = data
        self._cap = capacity

    def reserve(mut self, capacity: Int):
        if capacity > self._cap:
            self._grow(capacity)

    @always_inline
    def append(mut self, var value: Self.T):
        if self._len == self._cap:
            self._grow(max(2 * self._cap, 32))
        self._data.unsafe_offset(self._len).unsafe_write(value^)
        self._len += 1

    @always_inline
    def pop(mut self) -> Self.T:
        self._len -= 1
        return self._data.unsafe_offset(self._len).unsafe_take_pointee()

    @always_inline
    def unsafe_get(ref self, index: Int) -> ref[self] Self.T:
        return self._data.unsafe_offset(index).unsafe_mut_cast[origin_of(self).mut]().unsafe_origin_cast[origin_of(self)]()[]

    def shrink(mut self, length: Int):
        while self._len > length:
            self._len -= 1
            self._data.unsafe_offset(self._len).unsafe_deinit_pointee()
'''


def patch(folder, parts=None):
    engine = folder / 'fp' / 'matching' / '_engine.mojo'
    s = engine.read_text()
    if 'var memo = Optional[Dict[Int, Memo]]()' not in s:
        raise SystemExit('patch_engine_stack: apply patch_engine_setup.py first')
    s = sub(s, 'from std.memory import MaybeUninit\n', 'from std.memory import MaybeUninit\nfrom std.memory.alloc import unsafe_alloc\n',
            where='imports')
    anchor = '\n\ntrait _Signature:'
    s = sub(s, anchor, STACK + anchor, where='stack definition')
    found = s.count('values: List[R]')
    if found < 8:
        raise SystemExit(f'patch_engine_stack: expected at least 8 value-stack parameters, found {found}')
    s = s.replace('values: List[R]', 'values: _Stack[R]')
    s = sub(s, 'var values = List[R](capacity=32)', 'var values = _Stack[R](32)', where='run values')
    s = sub(s, 'var frames = List[_Frame[F]]()', 'var frames = _Stack[_Frame[F]](0)', where='run frames')
    engine.write_text(s)
