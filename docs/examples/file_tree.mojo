"""Recursive fields in a list or an optional: a folder holds entries, a shortcut may hold a target."""
import fp
from fp.adt import Data, Cases, Node, Value


@fieldwise_init
struct File(Copyable):
    var name: String
    var size: Int


@fieldwise_init
struct Folder[R: Value](Movable):
    var name: String
    var entries: List[Self.R]


@fieldwise_init
struct Shortcut[R: Value](Movable):
    var name: String
    var target: Optional[Self.R]


struct Tree(Data):
    comptime Layer[R: Value] = Cases[File, Folder[R], Shortcut[R]]


comptime T = Node[Tree]


def total_size(t: T) -> Int:
    """Every entry of a folder, and a shortcut's target when it has one, arrive evaluated."""
    return fp.match(t,
        lambda (f: File) -> Int: f.size,
        lambda (d: Folder[Int]) -> Int: sum_of(d.entries),
        lambda (l: Shortcut[Int]) -> Int: l.target.value() if l.target else 0)


def sum_of(sizes: List[Int]) -> Int:
    var total = 0
    for size in sizes:
        total += size
    return total


def listing(t: T) -> String:
    return fp.match(t,
        lambda (f: File) -> String: f.name,
        lambda (d: Folder[String]) -> String: d.name + "/{" + joined(d.entries) + "}",
        lambda (l: Shortcut[T]) -> String: l.name + "@")


def joined(items: List[String]) -> String:
    var text = String()
    for i in range(len(items)):
        text += (", " if i > 0 else "") + items[i]
    return text


def main():
    var notes: T = File("notes.txt", 120)
    var photos: T = Folder(String("photos"), [T(File("a.jpg", 2000)), T(File("b.jpg", 3000))])
    var home: T = Folder(String("home"), [notes, photos, T(Shortcut(String("latest"), Optional[T](photos))),
                                          T(Shortcut(String("broken"), Optional[T](None)))])
    print(listing(home))
    print(total_size(home))
