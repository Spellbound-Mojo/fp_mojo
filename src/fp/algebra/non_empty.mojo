"""Shape-preserving NonEmptyList operations through native List machinery."""
from std.builtin.rebind import rebind_var
from std.iter import IterableOwned
from fp.data.non_empty_list import NonEmptyList
from fp.callables.protocols import Unary, UnaryContract, BorrowCallable
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Traversable, Filterable, FunctorFilter, Applicative, Semigroup
from .instances import ListFamily, _ListElement
from .monoids import ListMonoid
from ._adapt import _map_as


@fieldwise_init
struct _NonEmptyAfter[T: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Restore the invariant after a cardinality-preserving List operation.

    The caller proves a non-empty source and an operation preserving its shape.
    An Applicative target must obey the Traversable laws: every successful
    collected branch has one payload per source element.
    """
    comptime Arg = List[Self.T]
    comptime Out = NonEmptyList[Self.T]
    def call(self, var arg: Self.Arg) -> Self.Out:
        var checked = Self.Out.from_list(arg^)
        debug_assert(Bool(checked), "shape-preserving operation produced an empty List")
        return checked.unsafe_take()


struct NonEmptyListSemigroup[T: Movable & Deinitable](Semigroup):
    """Ordered concatenation of non-empty lists, moving every element.

    There is no empty identity, so this is a Semigroup rather than a Monoid.
    It can be supplied directly to ValidationFamily and piped par_* methods.

    Parameters:
        T: The element or accumulated error type, including its origins.
    """
    comptime Value = NonEmptyList[Self.T]
    comptime Error = Never

    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        """Concatenate through ListMonoid, preserving non-emptiness.

        Args:
            left: The first non-empty list, consumed.
            right: The second non-empty list, consumed.

        Returns:
            All left elements followed by all right elements; no element copies.
        """
        var values = ListMonoid[Self.T].combine(left^.into_list(), right^.into_list())
        return _NonEmptyAfter[Self.T]().call(values^)


struct NonEmptyListFamily(Traversable, Filterable, FunctorFilter):
    """Non-empty mapping and traversal; filtering returns an ordinary List.

    Name this family explicitly in algebra operations or fluent pipelines.
    ListFamily owns callback invocation and traversal. Map preserves length;
    every successful traversal preserves the non-empty source shape. The target
    Applicative retains its failure, branching, evaluation and error policies.
    This family does not introduce a second collection loop.
    """
    comptime CarrierCompatible[V: Movable & Deinitable] = V == NonEmptyList[Self.Element[V]] if conforms_to(V, IterableOwned) else False
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == NonEmptyList[F.Arg]
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = NonEmptyList[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallable] = List[Self.Element[V]]
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallable] = P.Failure
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = List[_ListElement[F.Out]]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = G.Mapped[G.Collected[List[F.Arg], F], _NonEmptyAfter[G.Element[F.Out]]]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CommonError[G.CollectError[List[F.Arg], F], G.MapError[G.Collected[List[F.Arg], F], _NonEmptyAfter[G.Element[F.Out]]]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        """Consume and map each element once, left to right, preserving length.

        Parameters:
            V: The exact NonEmptyList carrier type.
            F: A repeatable callback retaining native types and errors.

        Args:
            f: The callback, consumed.
            value: The non-empty source, consumed.

        Returns:
            A non-empty list of transformed values in source order.

        Raises:
            The exact callback error; owned inputs and partial outputs are destroyed.
        """
        comptime assert Self.MapCompatible[V, F], "map: NonEmptyList carrier required"
        var mapped = ListFamily.map(f^, rebind_var[NonEmptyList[F.Arg]](value^).into_list())
        return _NonEmptyAfter[F.Out]().call(mapped^)

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallable](var predicate: P, var value: V
    ) raises P.Failure -> Self.Filtered[V, P]:
        """Retain accepted elements in a possibly empty native List.

        Parameters:
            V: The exact NonEmptyList carrier type.
            P: A repeatable borrowing Bool predicate.

        Args:
            predicate: The predicate, consumed; each element is borrowed once.
            value: The source, consumed.

        Returns:
            Accepted original values in order, possibly none.

        Raises:
            The predicate's exact native error.
        """
        comptime T = Self.Element[V]
        comptime assert Self.CarrierCompatible[V]
        return ListFamily.filter(predicate^, rebind_var[NonEmptyList[T]](value^).into_list())

    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        """Transform elements and retain present Optional results in a List.

        Parameters:
            V: The exact NonEmptyList carrier type.
            F: A repeatable callback returning Optional values.

        Args:
            f: The callback, consumed and called in source order.
            value: The source, consumed.

        Returns:
            Present transformed values in order; the List may be empty.

        Raises:
            The callback's exact native error.
        """
        comptime assert Self.MapCompatible[V, F], "filter_map: NonEmptyList carrier required"
        return ListFamily.filter_map(f^, rebind_var[NonEmptyList[F.Arg]](value^).into_list())

    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Traverse through G's collection kernel and restore each successful shape.

        Parameters:
            G: The target Applicative, with its existing evaluation and failure policy.
            V: The exact NonEmptyList source type.
            F: A repeatable callback returning a G carrier.

        Args:
            f: The callback, consumed; G determines whether failure stops calls.
            source: The non-empty source, consumed in order.

        Returns:
            G's carrier of NonEmptyList values, or G's failure or absent branches.

        Raises:
            The exact compatible callback and target errors; native errors stay raised.
        """
        comptime assert Self.TraverseCompatible[V, F], "traverse: NonEmptyList source required"
        comptime X = Self.TraverseError[G, V, F]
        var collected: G.Collected[List[F.Arg], F]
        try:
            collected = G.collect(f^, rebind_var[NonEmptyList[F.Arg]](source^).into_list())
        except error:
            comptime assert _ErrorCompatible[X, type_of(error)]
            _propagate_error[X](error^)
        comptime assert _ErrorCompatible[X, G.MapError[G.Collected[List[F.Arg], F], _NonEmptyAfter[G.Element[F.Out]]]]
        return _map_as[X, G](_NonEmptyAfter[G.Element[F.Out]](), collected^)
