"""Native iterator sources and advancement, without callback application."""
from std.iter import Iterator, IterableOwned, iter
from std.builtin.rebind import rebind_var, downcast


# A source is a native iterator, used as it is, or an owned collection
# (IterableOwned: List, Dict, Set, ...), consumed into its own native iterator.
# An iterator is never passed through iter(): a value that is both would restart.
comptime _Source[S: Movable & Deinitable]: Iterator = (
    downcast[S, Iterator] if conforms_to(S, Iterator)
    else downcast[S, IterableOwned].IteratorOwnedType
)


def _source[S: Movable & Deinitable](var source: S) -> _Source[S]:
    """Take a source as its native iterator."""
    comptime if conforms_to(S, Iterator):
        return rebind_var[_Source[S]](source^)
    else:
        return rebind_var[_Source[S]](iter(rebind_var[downcast[S, IterableOwned]](source^)))


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
