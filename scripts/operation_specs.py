"""Operation policies shared by selected and legacy syntax generators.

These descriptions select existing Mojo execution owners and their associated
types. Signature admission, parameter order and native ABI evidence stay with
each surface: in particular, selected admission must not silently strengthen a
legacy generic constraint. There is no generated runtime operation interpreter.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Terminal:
    name: str
    rule: str
    summary: str
    callback: bool = True
    smallest: bool = False

    @property
    def borrowing(self):
        return self.rule == "extremum"

    @property
    def driver(self):
        return "_" + self.rule

    def result(self, element, callback_result, combined_result):
        if self.borrowing:
            return f"Optional[{element}]"
        return callback_result if self.rule == "find_map" else combined_result

    def error(self, callback_error, monoid_error=None):
        return (
            f"_CommonError[{callback_error}, {monoid_error}]"
            if monoid_error is not None
            else callback_error
        )

    def runner(self, element, callback, monoid, error):
        if self.borrowing:
            return f"_ExtremumRun[{element}, {callback}, {self.smallest}]"
        if self.rule == "find_map":
            return f"_FindMapRun[{callback}]"
        return f"_FoldMapRun[{callback}, {monoid}, {error}]"

    def invoke(self, parameters, callback, source):
        bindings = f"[{parameters}]" if parameters else ""
        return f"{self.driver}{bindings}({callback}, {source})"


TERMINALS = {
    rule.name: rule
    for rule in (
        Terminal(
            "find_map",
            "find_map",
            "Return the first present transformed result, stopping without another pull.",
        ),
        Terminal(
            "fold_map",
            "fold_map",
            "Project and combine in order with a monoid; empty input returns its identity.",
        ),
        Terminal(
            "combine_all",
            "fold_map",
            "Combine in order with a monoid; empty input returns its identity.",
            callback=False,
        ),
        Terminal(
            "min_by",
            "extremum",
            "Return the element with the smallest key; empty input is absent and ties keep the first.",
            smallest=True,
        ),
        Terminal(
            "max_by",
            "extremum",
            "Return the element with the largest key; empty input is absent and ties keep the first.",
        ),
        Terminal(
            "sum",
            "fold_map",
            "Add in order from zero, preserving the numeric type and SIMD lanes.",
            callback=False,
        ),
        Terminal(
            "sum_by",
            "fold_map",
            "Project and add in one pass from zero, without an intermediate collection.",
        ),
    )
}


@dataclass(frozen=True)
class Traversal:
    name: str
    borrowing: bool = False
    sequence: bool = False
    discard: bool = False
    finish: str = ""
    filtering: bool = False

    @property
    def compact(self):
        return self.finish == "_CompactAfter"

    @property
    def flatten(self):
        return self.finish == "_FlattenAfter"

    @property
    def source_capability(self):
        return (
            "FunctorFilter"
            if self.compact
            else "Monad" if self.flatten else "Traversable"
        )

    @property
    def selected_family(self):
        return (
            "_SelectingTraversal"
            if self.compact
            else "_FlatteningTraversal" if self.flatten else "_Traversing"
        )

    def retained(self, element, target, callback, *, explicit=False):
        flag = f", {self.filtering}" if explicit or self.filtering else ""
        return f"_TraverseTap[{element}, {target}, {callback}{flag}]"

    def postprocess(self, family, target, source, callback):
        """Associated types for finishing inside the target effect."""
        if not self.finish:
            raise ValueError(f"{self.name} has no traversal postprocessing")
        traversed = f"{family}.Traversed[{target}, {source}, {callback}]"
        finish = f"{self.finish}[{family}, {target}.Element[{traversed}]]"
        before = f"{family}.TraverseError[{target}, {source}, {callback}]"
        after = f"{target}.MapError[{traversed}, {finish}]"
        return TraversalResult(
            traversed, finish, before, after, f"{target}.Mapped[{traversed}, {finish}]"
        )

    @property
    def summary(self):
        if self.filtering:
            return "Retain elements accepted by an effectful borrowing Bool predicate."
        if self.borrowing:
            return "Traverse effects and retain the original payloads on success."
        if self.discard:
            return "Traverse effects without retaining successful outputs."
        if self.flatten:
            return "Traverse effects and flatten one source-family layer inside the effect."
        return (
            "Traverse effects and retain present Optional payloads inside the effect."
        )


@dataclass(frozen=True)
class TraversalResult:
    traversed: str
    finish: str
    before: str
    after: str
    result: str

    @property
    def error(self):
        return f"_CommonError[{self.before}, {self.after}]"

    def invoke(self, family, target, source, callback, error, value, argument):
        return (
            f"_traverse_then[{family}, {target}, {source}, {callback}, {self.finish}, {error}]"
            f"({value}, {argument}, {self.finish}())"
        )


TRAVERSALS = {
    rule.name: rule
    for rule in (
        Traversal("traverse_void", discard=True),
        Traversal("traverse_tap", borrowing=True),
        Traversal("sequence_void", sequence=True, discard=True),
        Traversal("flat_traverse", finish="_FlattenAfter"),
        Traversal("flat_sequence", sequence=True, finish="_FlattenAfter"),
        Traversal("traverse_filter", finish="_CompactAfter"),
        Traversal(
            "filter_effect", borrowing=True, finish="_CompactAfter", filtering=True
        ),
        Traversal("sequence_filter", sequence=True, finish="_CompactAfter"),
    )
}
