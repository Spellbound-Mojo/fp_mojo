"""Overlay patch, applied after `patch_cells.py`: store small leaves in the handle.

A constructor of at most 4 bytes and 4-byte alignment that is trivially
copyable, movable and destructible (so it holds no `Node`) is stored in the
upper half of the 64-bit handle instead of a cell, for data types with at most
eight constructors: bits 0-2 hold the constructor's index and bit 3 marks an
inline value. Such a value has no cell, count, memo entry or release, its
height is 1, and its identity is its bits, so two equal inline values are
`is`-identical. `node[C]` still returns a reference: into the handle itself.

Parts: `inline` (the only part).
"""
import importlib.util
from pathlib import Path


def sub(text, old, new, count=1, where=''):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_inline: {where}: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


HELPERS = '''comptime _INLINE_FLAG = 8
"""Marks a handle that holds its constructor inline (types with at most 8 constructors)."""


def _inline_case[C: AnyType]() -> Bool:
    """Whether a constructor is stored in the handle: small, plain data, so no Node inside."""
    return (size_of[C]() <= 4 and align_of[C]() <= 4 and IsTriviallyCopyable[C]
            and IsTriviallyMovable[C] and IsTriviallyDeinitable[C])


def _any_inline[F: Data]() -> Bool:
    comptime S = F.Layer[Node[F]]
    comptime if S.count > 8:
        return False
    comptime for i in range(S.count):
        comptime if _inline_case[S.Case[i]]():
            return True
    return False


struct _Header(Movable):'''


def patch(folder, parts=None):
    data = folder / 'fp' / 'adt' / 'data.mojo'
    s = data.read_text()
    if 'struct _CellOf[' not in s:
        raise SystemExit('patch_inline: apply patch_cells.py first')
    s = sub(s, 'from std.sys.info import align_of\n',
            'from std.sys.info import align_of, size_of\nfrom std.traits.copyable import IsTriviallyCopyable\n'
            'from std.traits.movable import IsTriviallyMovable\nfrom std.traits.deinitable import IsTriviallyDeinitable\n',
            where='imports')
    s = sub(s, 'struct _Header(Movable):', HELPERS, where='helpers')

    # The index mask depends on whether the type has inline constructors.
    s = sub(s, '''    var _bits: Int
    """The cell's address, with the constructor's index in the low bits."""
''', '''    var _bits: Int
    """The cell's address, with the constructor's index in the low bits; or an inline value."""
    comptime _inlines = _any_inline[Self.F]()
    comptime _INDEX = 7 if Self._inlines else _TAG_MASK
''', where='fields')

    # Construction: inline when the constructor qualifies.
    s = sub(s, '''        comptime Stored = Self.Layer.Case[i]
        var height = _height[Self.F](value)
        var cell = unsafe_alloc''', '''        comptime Stored = Self.Layer.Case[i]
        comptime if Self._inlines and _inline_case[Stored]():
            var word = _INLINE_FLAG | i
            Pointer(to=word).unsafe_bitcast[UInt8]().unsafe_offset(4).unsafe_bitcast[Stored]().unsafe_write(rebind_var[Stored](value^))
            self._bits = word
            return
        var height = _height[Self.F](value)
        var cell = unsafe_alloc''', where='init')

    s = sub(s, '''        _ = copy._header()[].count.fetch_add[ordering=Ordering.RELAXED](1)
        self._bits = copy._bits''', '''        if not copy._inline():
            _ = copy._header()[].count.fetch_add[ordering=Ordering.RELAXED](1)
        self._bits = copy._bits''', where='copy')
    s = sub(s, '''        if not _drop_reference(self._header()):
            return
        if not _owns_child''', '''        if self._inline() or not _drop_reference(self._header()):
            return
        if not _owns_child''', where='deinit')

    s = sub(s, '''    @always_inline
    def _tag(self) -> Int:
        """The index of the constructor the value holds."""
        return self._bits & _TAG_MASK''', '''    @always_inline
    def _inline(self) -> Bool:
        """Whether the handle holds its constructor itself."""
        comptime if Self._inlines:
            return (self._bits & _INLINE_FLAG) != 0
        else:
            return False

    @always_inline
    def _tag(self) -> Int:
        """The index of the constructor the value holds."""
        return self._bits & Self._INDEX''', where='tag')
    s = sub(s, '''        """The cell's address: the value's identity."""
        return self._bits & ~_TAG_MASK''', '''        """The cell's address, or an inline value's bits: the value's identity."""
        if self._inline():
            return self._bits
        return self._bits & ~_TAG_MASK''', where='address')
    s = sub(s, '''    def _height(self) -> Int:
        return Int(self._header()[].height)''', '''    def _height(self) -> Int:
        if self._inline():
            return 1
        return Int(self._header()[].height)''', where='height')
    s = sub(s, '''        """Whether this handle is the only reference."""
        return self._header()[].count.load[ordering=Ordering.ACQUIRE]() == 1''', '''        """Whether this handle is the only reference to a cell (never for an inline value)."""
        return not self._inline() and self._header()[].count.load[ordering=Ordering.ACQUIRE]() == 1''', where='unique')
    s = sub(s, '''        """Whether another handle refers to the value too."""
        return self._header()[].count.load[ordering=Ordering.RELAXED]() > 1''', '''        """Whether another handle refers to the value's cell too (never for an inline value)."""
        return not self._inline() and self._header()[].count.load[ordering=Ordering.RELAXED]() > 1''', where='shared')
    s = sub(s, '''        """The stored constructor `i`; the value must hold it."""
        var cell = ''', '''        """The stored constructor `i`; the value must hold it."""
        comptime if Self._inlines and _inline_case[Self.Layer.Case[i]]():
            return Pointer(to=self._bits).unsafe_bitcast[UInt8]().unsafe_offset(4).unsafe_bitcast[Self.Layer.Case[i]]().as_imm().unsafe_origin_cast[origin_of(self)]()[]
        var cell = ''', where='get')
    data.write_text(s)
