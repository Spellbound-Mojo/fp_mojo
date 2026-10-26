"""Native iterator sources and advancement, without callback application."""
from std.iter import Iterator, IterableOwned, iter
from std.builtin.rebind import rebind_var, downcast
from std.reflection import reflect


comptime _OwnedIterator[S: Movable & Deinitable] = downcast[S, IterableOwned].IteratorOwnedType
comptime _OwnedElement[S: Movable & Deinitable] = downcast[_OwnedIterator[S].Element, Movable & Deinitable]


def _array_source[S: Movable & Deinitable]() -> Bool:
    # Array does not expose its length through IterableOwned. Nominal reflection
    # only selects buffering; element types still come from the native protocol.
    return reflect[S].name().startswith("std.collections.array.Array[")


def _buffer_owned[S: Movable & Deinitable](var source: S) -> List[_OwnedElement[S]]:
    # Keep the native iterator in this frame: Mojo 1.2's Array owning iterator
    # destroys transferred slots when moved. Draining it in place is safe.
    var result = List[_OwnedElement[S]]()
    for var item in rebind_var[downcast[S, IterableOwned]](source^):
        result.append(rebind_var[_OwnedElement[S]](item^))
    return result^


struct _CollectionSource[S: Movable & Deinitable](Iterator):
    comptime Element = _OwnedElement[Self.S]
    comptime Cursor: Iterator = (
        List[Self.Element].IteratorOwnedType if _array_source[Self.S]() else _OwnedIterator[Self.S]
    )
    var cursor: Self.Cursor

    def __init__(out self, var source: Self.S):
        comptime if _array_source[Self.S]():
            self.cursor = rebind_var[Self.Cursor](iter(_buffer_owned(source^)))
        else:
            self.cursor = rebind_var[Self.Cursor](iter(rebind_var[downcast[Self.S, IterableOwned]](source^)))

    def __next__(mut self) raises StopIteration -> Self.Element:
        return rebind_var[Self.Element](self.cursor.__next__())


# A source is a native iterator, used as it is, or an owned collection
# (IterableOwned: List, Dict, Set, ...), consumed into its own native iterator.
# An iterator is never passed through iter(): a value that is both would restart.
comptime _Source[S: Movable & Deinitable]: Iterator = (
    downcast[S, Iterator] if conforms_to(S, Iterator)
    else _CollectionSource[S]
)


def _source[S: Movable & Deinitable](var source: S) -> _Source[S]:
    """Take a source as its native iterator."""
    comptime if conforms_to(S, Iterator):
        return rebind_var[_Source[S]](source^)
    else:
        return rebind_var[_Source[S]](_CollectionSource[S](source^))


def _next_fused[I: Iterator](
    mut source: I, mut done: Bool
) raises StopIteration -> I.Element:
    """Remember exhaustion and never pull the source again after it ends."""
    if done:
        raise StopIteration()
    try:
        return source.__next__()
    except:
        done = True
        raise StopIteration()


def _next_optional[T: Movable & Deinitable, I: Iterator](mut source: I) -> Optional[T]:
    """Read once; an absent outer Optional means only source exhaustion."""
    try:
        # Public terminal signatures prove I.Element == T before refinement.
        return Optional(rebind_var[T](source.__next__()))
    except:
        return None


def _next_optional_fused[T: Movable & Deinitable, I: Iterator](
    mut source: I, mut done: Bool
) -> Optional[T]:
    """Read a live source once, remembering absence without polling again."""
    if done: return None
    var value = _next_optional[T](source)
    done = not value
    return value^
