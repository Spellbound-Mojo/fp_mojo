"""Runs: what Mojo 1.2 struct-field reflection sees when walking a payload type.

For each type, print its base name, whether it is a struct, its direct fields,
and the base names of every `Pointer` met by a recursive walk of its field tree.
`UnsafePointer`, `OpaquePointer`, and `Pointer` are one struct in Mojo 1.2.
"""
from std.atomic import Atomic
from std.memory import ArcPointer, OwnedPointer
from std.collections import Dict


def _walk[T: AnyType](depth: Int):
    # Every branch is an elif: code after a `return` inside `comptime if`
    # is still elaborated, so field reflection on a non-struct would fail.
    comptime r = reflect[T]
    comptime if not r.is_struct():
        print("  " * depth, "<non-struct>")
    elif r.base_name() == "Pointer":
        print("  " * depth, "POINTER:", r.name())
    else:
        print("  " * depth, r.base_name(), "fields=", r.field_count())
        comptime types = r.field_types()
        comptime for i in range(r.field_count()):
            print("  " * depth, " field", i)
            _walk[types[i]](depth + 2)


struct Raw(Movable):
    var address: Pointer[Int, MutUntrackedOrigin]


struct Opaque(Movable):
    var handle: MutOpaquePointer[MutUntrackedOrigin]


struct Shared(Movable):
    var data: ArcPointer[List[Int]]


struct Nested(Movable):
    var name: String
    var inner: Shared
    var flag: Bool


struct Borrowing[o: ImmOrigin](Movable):
    var view: Pointer[List[Int], Self.o]


def thin_function(value: Int) -> Int:
    return value + 1


def main():
    print("== Int"); _walk[Int](1)
    print("== Bool"); _walk[Bool](1)
    print("== String"); _walk[String](1)
    print("== List[Int]"); _walk[List[Int]](1)
    print("== Optional[String]"); _walk[Optional[String]](1)
    print("== Dict[String, Int]"); _walk[Dict[String, Int]](1)
    print("== OwnedPointer[Int]"); _walk[OwnedPointer[Int]](1)
    print("== ArcPointer[Int]"); _walk[ArcPointer[Int]](1)
    print("== Atomic[UInt8]"); _walk[Atomic[UInt8]](1)
    print("== Tuple[Int, String]"); _walk[Tuple[Int, String]](1)
    print("== Raw"); _walk[Raw](1)
    print("== Opaque"); _walk[Opaque](1)
    print("== Nested"); _walk[Nested](1)
    print("== Borrowing"); _walk[Borrowing[ImmUntrackedOrigin]](1)
    print("== thin function"); _walk[type_of(thin_function)](1)
