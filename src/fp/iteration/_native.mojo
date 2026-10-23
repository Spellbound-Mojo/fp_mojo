"""Native adapter construction over the canonical consuming source rule."""
from std.iter import Iterator, IterableOwned, _ZipIterator, _ChainedIterator
from std.builtin.variadics import TypeList
from std.builtin.rebind import rebind_var
from std.memory import MaybeUninit
from ._advance import _Source, _source


@fieldwise_init
struct _OwnedSource[S: Movable & Deinitable](IterableOwned, Movable):
    """Allow a native factory to consume a source without restarting an iterator."""
    comptime IteratorOwnedType = _Source[Self.S]
    var source: Self.S
    def _into_source(deinit self) -> Self.IteratorOwnedType:
        return _source(self.source^)
    def __iter__(var self) -> Self.IteratorOwnedType:
        return self^._into_source()


comptime _NativeSource[S: Movable & Deinitable]: Iterator = _Source[S]
comptime _NativeSources[*Ss: Movable & Deinitable] = TypeList[Trait=Movable & Deinitable, Ss.values]().map[_NativeSource]()
comptime _NativeTail[I: Iterator, *Ss: Movable & Deinitable] = TypeList._concat[TypeList.of[Trait=Iterator, I]().values, _NativeSources[*Ss].values]()
comptime _SameSource[T: Movable, S: Movable & Deinitable]: Bool = _Source[S].Element == T


def _source_pack[*Ss: Movable & Deinitable](var *sources: *Ss) -> Tuple[*_NativeSources[*Ss]]:
    comptime Out = Tuple[*_NativeSources[*Ss]]
    var result = MaybeUninit[Out]()
    def store[i: Int](var value: sources.Ts[i]) {ref result}:
        comptime assert Out.Ts[i] == _Source[sources.Ts[i]]
        Pointer(to=result.unsafe_ptr()[][i]).unsafe_write(rebind_var[Out.Ts[i]](_source(value^)))
    sources^.consume_elements(store)
    return result^.unsafe_assume_init()


# Mojo 1.1 can forward an owned VariadicPack but cannot unpack a Tuple into a
# pack or map a pack into _OwnedSource values. Its zip/chain factories also call
# iter on every input, which restarts some iterators and excludes Iterator-only
# sources. Normalize once, then initialize the pinned native adapter storage.
# All advancement, bounds, incomplete-zip cleanup and exhaustion remain native.
# No callback can raise during construction and every slot is initialized once.
def _native_zip[S: Movable & Deinitable, *Ss: Movable & Deinitable](var first: S, var *sources: *Ss,
    out result: _ZipIterator[MutUntrackedOrigin, *_NativeTail[_Source[S], *Ss]]):
    __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(result))
    var initialized = Tuple(_source(first^)).concat(_source_pack(*sources^))
    comptime assert type_of(initialized) == type_of(result._values)
    Pointer(to=result._values).unsafe_write(rebind_var[type_of(result._values)](initialized^))


def _native_chain[S: Movable & Deinitable, *Ss: Movable & Deinitable](var first: S, var *sources: *Ss,
    out result: _ChainedIterator[*_NativeTail[_Source[S], *Ss]]):
    __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(result))
    var initialized = Tuple(_source(first^)).concat(_source_pack(*sources^))
    comptime assert type_of(initialized) == type_of(result._iterators)
    Pointer(to=result._iterators).unsafe_write(rebind_var[type_of(result._iterators)](initialized^))
    result._idx = 0
