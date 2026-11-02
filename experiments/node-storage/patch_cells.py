"""Overlay patch: compact Node cells with the constructor in the handle.

Replaces `Node`'s `ArcPointer[_Cell]` (two 64-bit counts, a 64-bit height and a
`Variant` padded to the largest constructor: a 48-byte allocation, which the
allocator rounds to 64) with one allocation per value holding a 32-bit count,
a 32-bit height and that constructor alone. The handle is the cell's address
with the constructor's index in its low 4 bits (cells are 16-byte aligned).

Behavior is unchanged: copying shares, values are immutable, release runs in a
loop, and the last handle frees the cell. Dropping a handle that is the only
reference skips the atomic decrement. Callers outside `Node` (the matching
engine and the inline matcher) go through new internal methods instead of the
cell: `_tag`, `_get[i]`, `_height`, `_unique`, `_shared`, `_address`.

Parts: `cells` (all of the above; the only part).
"""


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_cells: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


NODE = '''
# ----------------------------------------------------------------- cells

comptime _TAG_BITS = 4
"""The low handle bits that hold the constructor's index."""
comptime _TAG_MASK = (1 << _TAG_BITS) - 1
comptime _CELL_ALIGN = 1 << _TAG_BITS


struct _Header(Movable):
    """The start of every cell: the reference count and the height."""

    var count: Atomic[UInt32]
    var height: UInt32

    def __init__(out self, height: Int):
        self.count = Atomic[UInt32](1)
        self.height = UInt32(height)


struct _CellOf[C: Value](Movable):
    """One value's cell: the header, then the one constructor it holds."""

    var header: _Header
    var value: Self.C

    def __init__(out self, height: Int, var value: Self.C):
        self.header = _Header(height)
        self.value = value^


@always_inline
def _drop_reference(header: Pointer[_Header, MutUntrackedOrigin]) -> Bool:
    """Drop one reference; True when it was the last, so the caller owns the cell.

    A count of one seen by the holder of a reference cannot change: no other
    handle exists to copy it. The ACQUIRE load (or fence) orders every earlier
    release of the value before its destruction.
    """
    if header[].count.load[ordering=Ordering.ACQUIRE]() == 1:
        return True
    if header[].count.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
        return False
    fence[ordering=Ordering.ACQUIRE]()
    return True


def _free_cell[F: Data](bits: Int):
    """Destroy the constructor in the cell `bits` names and free the cell."""
    comptime S = F.Layer[Node[F]]
    var tag = bits & _TAG_MASK
    var address = bits & ~_TAG_MASK
    comptime for i in range(S.count):
        if tag == i:
            var cell = Pointer[_CellOf[S.Case[i]], MutUntrackedOrigin](unsafe_from_address=address)
            cell.unsafe_deinit_pointee()
            cell.unsafe_free()
            return


trait _NodeType:
    """Implemented by `Node` alone, so generic code can recognize a value of a data type."""

    comptime Of: Data


struct Node[F: Data](ImplicitlyCopyable, Movable, _NodeType):
    """An immutable value of data type `F`: one constructor whose recursive fields hold Nodes.

    A Node can only refer to Nodes that already exist and cannot change after
    construction, so a Node and everything it reaches form a finite acyclic
    graph. Copying a Node shares it in constant time. Each Node stores its
    height, the longest path to a leaf, and is released in a loop, so values of
    any depth can be built and dropped.

    Parameters:
        F: The data type.
    """

    comptime Layer = Self.F.Layer[Node[Self.F]]
    """The stored constructors, with recursive fields holding Nodes."""
    comptime Of: Data = Self.F
    """The data type."""
    var _bits: Int
    """The cell's address, with the constructor's index in the low bits."""

    @implicit
    def __init__[C: Value](out self, var value: C):
        """Store one constructor; its recursive fields hold existing Nodes.

        Parameters:
            C: The constructor, with recursive fields of type `Node[F]`.

        Args:
            value: The constructor value, moved in.
        """
        comptime assert _admit_data[Self.F]()
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, (
            "Node: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
            + " with Node children")
        comptime assert Self.Layer.count <= _TAG_MASK + 1, "Node (cell probe): at most 16 constructors"
        comptime Stored = Self.Layer.Case[i]
        var height = _height[Self.F](value)
        var cell = unsafe_alloc[_CellOf[Stored]](1, alignment=max(_CELL_ALIGN, align_of[_CellOf[Stored]]()))
        cell.unsafe_write(_CellOf[Stored](height, rebind_var[Stored](value^)))
        self._bits = Int(cell) | i

    def __init__(out self, *, copy: Self):
        """Share `copy`."""
        _ = copy._header()[].count.fetch_add[ordering=Ordering.RELAXED](1)
        self._bits = copy._bits

    def __deinit__(deinit self):
        """Release the value; children it alone owned are released in a loop, not recursively."""
        if not _drop_reference(self._header()):
            return
        if not _owns_child[Self.F](self):
            # Releasing the cell only shares its children. This is also how a
            # value the loop below releases ends: the loop already holds its
            # children, so no second work list is allocated per value.
            _free_cell[Self.F](self._bits)
            return
        var pending = List[Node[Self.F]]()
        _collect_children[Self.F](self, pending)
        _free_cell[Self.F](self._bits)
        while pending:
            var node = pending.pop()
            if node._unique():
                _collect_children[Self.F](node, pending)
            # `node` is released here; its children are still held by `pending`,
            # so its own release only shares them and does not descend.

    @always_inline
    def _header(self) -> Pointer[_Header, MutUntrackedOrigin]:
        return Pointer[_Header, MutUntrackedOrigin](unsafe_from_address=self._bits & ~_TAG_MASK)

    @always_inline
    def _tag(self) -> Int:
        """The index of the constructor the value holds."""
        return self._bits & _TAG_MASK

    @always_inline
    def _address(self) -> Int:
        """The cell's address: the value's identity."""
        return self._bits & ~_TAG_MASK

    @always_inline
    def _height(self) -> Int:
        return Int(self._header()[].height)

    @always_inline
    def _unique(self) -> Bool:
        """Whether this handle is the only reference."""
        return self._header()[].count.load[ordering=Ordering.ACQUIRE]() == 1

    @always_inline
    def _shared(self) -> Bool:
        """Whether another handle refers to the value too."""
        return self._header()[].count.load[ordering=Ordering.RELAXED]() > 1

    @always_inline
    def _get[i: Int](self) -> ref[self] Self.Layer.Case[i]:
        """The stored constructor `i`; the value must hold it."""
        var cell = Pointer[_CellOf[Self.Layer.Case[i]], MutUntrackedOrigin](unsafe_from_address=self._address())
        return Pointer(to=cell[].value).as_imm().unsafe_origin_cast[origin_of(self)]()[]

    def isa[C: AnyType](self) -> Bool:
        """Whether the value is constructor `C` (with Node children).

        Parameters:
            C: A constructor of `F`.

        Returns:
            True when the value holds `C`.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Node.isa: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        return self._tag() == i

    def __getitem_param__[C: AnyType](self) -> ref[self] C:
        """The constructor the value holds, which must be `C`.

        Parameters:
            C: A constructor of `F`, with Node children.

        Returns:
            A reference to the stored constructor.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Node: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        debug_assert[assert_mode="safe"](self._tag() == i, "Node: wrong constructor")
        return rebind[C](self._get[i]())

    def __eq__[C: Equatable & Value](self, other: C) -> Bool:
        """Whether the value is constructor `C` and equal to `other`.

        Parameters:
            C: An `Equatable` constructor of `F`.

        Args:
            other: The constructor value to compare with.

        Returns:
            True when the constructor matches and its value equals `other`.
        """
        comptime i = _index[Self.Layer, C]()
        comptime assert i >= 0, "Node: " + reflect[C].name() + " is not a constructor of " + reflect[Self.F].name()
        return self._tag() == i and rebind[C](self._get[i]()) == other

    def __is__(self, other: Self) -> Bool:
        """Whether both are the same shared value."""
        return self._address() == other._address()


def _collect_children[F: Data](node: Node[F], mut into: List[Node[F]]):
    comptime S = F.Layer[Node[F]]
    var tag = node._tag()
    comptime for i in range(S.count):
        if tag == i:
            _collect[F](node._get[i](), into)
            return


def _owns_child[F: Data](node: Node[F]) -> Bool:
    """Whether the stored constructor holds a child that no other handle shares."""
    comptime S = F.Layer[Node[F]]
    var tag = node._tag()
    comptime for i in range(S.count):
        if tag == i:
            return _sole_owner[F](node._get[i]())
    return False

'''


def patch(folder, parts=None):
    data = folder / 'fp' / 'adt' / 'data.mojo'
    s = data.read_text()
    s = sub(s, 'from std.memory import ArcPointer\n',
            'from std.memory.alloc import unsafe_alloc\nfrom std.atomic import Atomic, Ordering, fence\nfrom std.sys.info import align_of\n',
            where='data imports')
    s = sub(s, '._cell[].height)', '._height())', count=3, where='heights')
    # Three in _sole_owner; the fourth is in the destructor this patch replaces below.
    s = sub(s, '._cell.count() == 1', '._unique()', count=4, where='sole owner')
    start = s.index('struct _Cell[F: Data](Movable):')
    end = s.index('# ----------------------------------------------------------------- inline values')
    s = s[:start] + NODE.lstrip('\n') + '\n' + s[end:]
    data.write_text(s)

    engine = folder / 'fp' / 'matching' / '_engine.mojo'
    s = engine.read_text()
    s = sub(s, 'return Int(Pointer(to=node._cell[]))', 'return node._address()', where='engine key')
    s = sub(s, '''    ref layer = _node_of(frame, owned)[]._cell[].layer
    frame.sub = 0
    comptime for i in range(S.count):
        if S.is_case[i](layer):''', '''    var tag = _node_of(frame, owned)[]._tag()
    frame.sub = 0
    comptime for i in range(S.count):
        if tag == i:''', where='engine enter')
    s = sub(s, 'if frame.handle[]._cell.count() > 1:', 'if frame.handle[]._shared():', where='engine memo')
    s = sub(s, '''    ref layer = frame.handle[]._cell[].layer
    frame.base = len(values)
    comptime for i in range(S.count):
        if S.is_case[i](layer):''', '''    var tag = frame.handle[]._tag()
    frame.base = len(values)
    comptime for i in range(S.count):
        if tag == i:''', where='engine start')
    s = sub(s, 'if target._cell[].height >= _node_of(frame, owned)[]._cell[].height:',
            'if target._height() >= _node_of(frame, owned)[]._height():', where='engine next')
    s = sub(s, 'ref stored = F.Layer[Node[F]].get[i](node[]._cell[].layer)', 'ref stored = node[]._get[i]()', where='engine call')
    s = sub(s, 'ref stored = S.get[i](node[]._cell[].layer)', 'ref stored = node[]._get[i]()', where='engine steps')
    engine.write_text(s)

    inline = folder / 'fp' / 'matching' / '_inline.mojo'
    s = inline.read_text()
    s = sub(s, 'return F.Layer[Node[F]].is_case[k](rebind[Node[F]](subject)._cell[].layer)',
            'return rebind[Node[F]](subject)._tag() == k', where='inline case')
    s = sub(s, 'ref stored = F.Layer[Node[F]].get[k](rebind[Node[F]](subject)._cell[].layer)',
            'ref stored = rebind[Node[F]](subject)._get[k]()', where='inline view')
    inline.write_text(s)
