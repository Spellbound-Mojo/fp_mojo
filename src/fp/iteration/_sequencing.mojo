"""Native lazy mapping boundary for the shared sequencing continuations."""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Functor
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import RepeatableUnary
from ._advance import _Source, _source
from .adapters import _Map, FlatMapIterator, flatten


struct _IteratorMap(Functor):
    # Only mapping is needed to retain a value in each inner branch. Native
    # iterators keep their own flattening and advancement; no Monad is emulated.
    comptime Element[V: Movable & Deinitable] = downcast[_Source[V].Element, Movable & Deinitable]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _Map[F.Arg, F.Out, _Source[V], F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime assert _Source[V].Element == F.Arg
        comptime assert RepeatableUnary[F] and F.Error == Never, "lazy sequencing: non-raising repeatable callback required"
        return _Map[F.Arg, F.Out, _Source[V], F](f^, _source(value^), False)


def _bind_iterator[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var source: V
) -> FlatMapIterator[F.Arg, F.Out, _Source[V], F]:
    var mapped = _IteratorMap.map(function^, source^)
    return flatten(mapped^)
