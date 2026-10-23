"""Effectful search, mapped reduction and Optional filtering."""
from fp.iteration import iterated, sequence_filter
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid
from fp.data import Result, Ok


def selected(value: Int) -> Optional[Bool]:
    return Optional(value == 3)


def label(var value: Int) -> Result[Optional[String], String]:
    return Ok(Optional("found " + String(value)) if value == 2 else Optional[String]())


def text(var value: Int) -> Optional[String]:
    return Optional(String(value))


def main() raises:
    print("find:", iterated(range(6)).find_effect[OptionalFamily](selected).value().value())
    print("find map:", iterated(range(6)).find_map_effect[ResultFamily[String]](label).raise_on_err().value())
    print("fold map:", iterated(range(1, 4)).fold_map_effect[OptionalFamily, StringMonoid](text).value())
    var effects: List[Optional[Optional[Int]]] = [Optional(Optional(1)), Optional(Optional[Int]()), Optional(Optional(3))]
    print("sequence filter:", sequence_filter[OptionalFamily](effects^).value())
