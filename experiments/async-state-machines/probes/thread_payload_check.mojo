"""Runs: a conservative compile-time thread-hazard classifier built from Mojo 1.2 reflection.

Classifies a payload type without instantiating it:

- `0` no hazard found; `1` a raw `Pointer` field in a non-standard-library
  struct; `2` shared ownership (`ArcPointer` or `WeakPointer`) whose payload
  reflection cannot inspect.
- A type conforming to the opt-in `ThreadShareable` marker is accepted as is:
  its author asserts it synchronizes itself.
- Standard-library types are trusted owners of their allocations. The walk
  enters their elements only through `IterableOwned` (List, Optional); other
  parameters (Dict values, Variant, Tuple, OwnedPointer payloads) are invisible.

The classifier is a heuristic, not a proof; see async-thread-safety.md.
"""
from std.builtin.rebind import downcast
from std.memory import ArcPointer, OwnedPointer
from std.collections import Dict
from std.atomic import Atomic


trait ThreadShareable:
    """Opt-in marker: the author asserts the type may be shared between threads."""
    pass


comptime _NONE = 0
comptime _RAW = 1
comptime _SHARED = 2


def _max(a: Int, b: Int) -> Int:
    return a if a > b else b


def _hazard[T: AnyType]() -> Int:
    comptime r = reflect[T]
    comptime if conforms_to(T, ThreadShareable):
        return _NONE
    elif not r.is_struct():
        return _NONE
    elif r.base_name() == "Pointer":
        return _RAW
    elif r.base_name() == "ArcPointer" or r.base_name() == "WeakPointer":
        return _SHARED
    elif r.name[qualified_builtins=True]().startswith("std."):
        comptime if conforms_to(T, IterableOwned):
            return _hazard[downcast[T, IterableOwned].IteratorOwnedType.Element]()
        else:
            return _NONE
    else:
        var worst = _NONE
        comptime types = r.field_types()
        comptime for i in range(r.field_count()):
            worst = _max(worst, _hazard[types[i]]())
        return worst


# Compile-time admission, as a library constructor would spell it.
def admit[T: Movable](var value: T) -> T:
    comptime assert _hazard[T]() == _NONE, "payload may be thread-confined: " + reflect[T].name()
    return value^


struct Raw(Movable):
    var address: Pointer[Int, MutUntrackedOrigin]


@fieldwise_init
struct Shared(Movable):
    var data: ArcPointer[List[Int]]


struct Wrapped(Movable):
    var name: String
    var inner: Shared


struct Counter(Movable, ThreadShareable):
    # The author synchronizes every access, so the marker is honest here.
    var count: ArcPointer[Atomic[UInt64]]


@fieldwise_init
struct Plain(Movable):
    var name: String
    var values: List[Int]
    var maybe: Optional[String]


struct Borrowing[o: ImmOrigin](Movable):
    var view: Pointer[List[Int], Self.o]


def show[T: AnyType](label: StaticString):
    print(label, _hazard[T]())


def main():
    show[Int]("Int")
    show[String]("String")
    show[List[String]]("List[String]")
    show[Plain]("Plain")
    show[Counter]("Counter (marked)")
    show[Raw]("Raw")
    show[Borrowing[ImmUntrackedOrigin]]("Borrowing")
    show[Shared]("Shared")
    show[Wrapped]("Wrapped")
    show[List[Shared]]("List[Shared]")
    show[Optional[ArcPointer[Int]]]("Optional[ArcPointer[Int]]")
    # Known holes: these hide a hazard from the walk.
    show[Dict[String, Shared]]("Dict[String, Shared] (hole)")
    show[Tuple[Int, Shared]]("Tuple[Int, Shared] (hole)")
    show[OwnedPointer[Shared]]("OwnedPointer[Shared] (hole)")
    show[ArcPointer[Atomic[UInt64]]]("ArcPointer[Atomic] (false positive)")
    var plain = admit(Plain(String("x"), List[Int](), None))
    print("admitted", plain.name)
