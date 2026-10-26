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


@dataclass(frozen=True)
class Sequencing:
    name: str
    mode: str
    retained: str
    legacy_summary: str
    selected_summary: str

    @property
    def factory(self):
        return self.mode == "thunk"

    @property
    def retain(self):
        return self.retained != "produced"

    @property
    def paired(self):
        return self.retained == "pair"

    @property
    def result_output(self):
        return {"original": "source", "pair": "pair", "produced": "first"}[
            self.retained
        ]

    def adapt(self, element, callback, build):
        """Give a factory the ignored input expected by the shared continuations."""
        if self.factory:
            callback = f"_IgnoreInput[{element}, {callback}]"
            build = f"{callback}({build})"
        return callback, build

    def continuation(self, element, family, callback):
        """Select the existing generic bind continuation, without choosing admission."""
        if not self.retain:
            return f"_BorrowedUnary[{element}, {callback}]"
        extra = ", False, True" if self.paired else ""
        return f"_EffectRetain[{element}, {family}, {callback}{extra}]"


# Iteration and arbitrary Monad families share the callback/retention decisions.
# Their repeatability, branching, errors and timing remain with the selected
# family and admission surface. Result reuses only those semantic decisions.
SEQUENCING = {
    op.name: op
    for op in (
        Sequencing(
            "flat_tap",
            "borrow",
            "original",
            "Sequence a borrowing effectful callback and retain each original value.",
            "Sequence a borrowing effect and retain each original payload.",
        ),
        Sequencing(
            "flat_pair_with",
            "borrow",
            "pair",
            "Sequence a borrowing effectful projection and pair each success with its original.",
            "Sequence a borrowing effect and pair each original with each successful projection.",
        ),
        Sequencing(
            "followed_by",
            "thunk",
            "produced",
            "Sequence a zero-argument factory and keep its produced values.",
            "Sequence a factory and keep its produced payloads.",
        ),
        Sequencing(
            "before",
            "thunk",
            "original",
            "Sequence a zero-argument factory and retain each original value.",
            "Sequence a factory and retain each original payload.",
        ),
    )
}


# Result semantics are shared; native inference policy stays with each emitter.
RESULT_DOCS = {
    "flat_tap": (
        "Sequence a borrowed Result projection and retain the original success "
        "value.",
        "The projection runs only on Ok. Its Err replaces the success; its Ok "
        "payload is discarded. The original payload is moved, never copied.",
    ),
    "flat_pair_with": (
        "Sequence a borrowed Result projection and retain both success " "values.",
        "The projection runs only on Ok. Its Err replaces the success; its "
        "Ok payload is paired with the moved original. Neither payload "
        "needs Copyable.",
    ),
    "followed_by": (
        "On success, call a zero-argument factory and return its Result.",
        "The factory runs at most once and is skipped on Err. The preceding "
        "success payload is discarded.",
    ),
    "before": (
        "On success, call a zero-argument factory and retain the original value.",
        "The factory runs at most once and is skipped on Err. Its Err replaces the "
        "success; its Ok payload is discarded. The original payload is moved, "
        "never copied.",
    ),
    "ensure": (
        "Keep an accepted success or construct a stored error from its borrowed "
        "value.",
        "The predicate runs only on Ok; the error factory runs only when the "
        "predicate returns False. Both borrow the success payload. The original "
        "Err passes through unchanged.",
    ),
    "recover": (
        "Recover a stored error as a success, retaining the Result error type.",
        "The callback consumes the error and returns the original success type. "
        "Ok passes through unchanged. This returns Result[T, E], not an unwrapped "
        "value.",
    ),
    "tap_err": (
        "Inspect a borrowed stored error and retain the Result.",
        "The inspector runs only on Err. Its return value is discarded; the error "
        "is moved back unchanged. Ok passes through without inspection.",
    ),
    "recover_if": (
        "Recover a matching stored error as a success.",
        "Only Err runs the borrowing predicate. On True, the recovery consumes "
        "the error and returns the success type. On False, the original error "
        "remains. The stored error type stays unchanged.",
    ),
    "or_else_if": (
        "Continue a matching stored error with a Result.",
        "Only Err runs the borrowing predicate. On True, the recovery consumes "
        "the error and returns Result[T, E]; on False, the original error "
        "remains. Both success and stored error types stay unchanged.",
    ),
    "flat_tap_err": (
        "Sequence a borrowed error projection and retain the original error "
        "on success.",
        "The projection runs only on Err and must return Result[U, E]. Its "
        "Ok payload is discarded and the original error is retained; its Err "
        "replaces that error. Ok passes through unchanged.",
    ),
    "attempt_tap": (
        "Sequence an observer of the whole Result and retain its outcome on "
        "observer success.",
        "The observer borrows the entire Result, runs once on either branch "
        "and returns Result[U, E]. Its Ok payload is discarded and the "
        "original Result is retained; its Err replaces the original outcome. "
        "Native raised errors remain raised.",
    ),
    "map_err": (
        "Transform the stored error of a Result.",
        "This forwards to Result.map_err, including changes to the stored error "
        "type. Ok passes through unchanged.",
    ),
    "or_else": (
        "Continue a failed Result with the callback Result.",
        "This forwards to Result.or_else, including changes to the stored error "
        "type. The success type stays the same; Ok passes through unchanged.",
    ),
}

RESULT_OUTCOMES = {
    "map_both": (
        "Transform either payload, preserving its Result constructor.",
        "The selected handler consumes its payload. The success and stored error "
        "types may both change.",
    ),
    "redeem": (
        "Turn either branch into a success with a common value type.",
        "Both handlers return the same value type. The selected result is wrapped "
        "in Ok, retaining the original stored error type.",
    ),
    "redeem_with": (
        "Continue either branch with the selected handler Result.",
        "Both handlers return the same Result type, which may change both "
        "success and stored error types. Only the original branch selects a "
        "handler; a returned Err never invokes the other handler.",
    ),
}


@dataclass(frozen=True)
class ResultCallback:
    mode: str
    payload: str
    argument: str = "function"

    def input(self, success, error):
        return {
            "success": success,
            "error": error,
            "whole": f"Result[{success}, {error}]",
            "none": "",
        }[self.payload]


@dataclass(frozen=True)
class ResultOperation:
    name: str
    callbacks: tuple[ResultCallback, ...]
    output: str = "source"
    first_rule: str = ""
    second_rule: str = ""
    sequence: bool = False
    outcome: bool = False

    @property
    def documentation(self):
        return (RESULT_OUTCOMES if self.outcome else RESULT_DOCS)[self.name]

    @property
    def conditional(self):
        return len(self.callbacks) == 2 and not self.outcome

    @property
    def selective(self):
        return self.conditional and self.callbacks[0].payload == "error"

    def result(self, success, error, first, second="", *, value):
        if self.output == "source":
            return f"Result[{success}, {error}]"
        if self.output == "pair":
            return f"Result[Tuple[{success}, {value(first)}], {error}]"
        if self.output == "first":
            return first
        if self.output == "error":
            return f"Result[{success}, {first}]"
        if self.output == "both":
            return f"Result[{first}, {second}]"
        if self.output == "success":
            return f"Result[{first}, {error}]"
        raise ValueError(self.output)

    def first_constraints(
        self, success, error, first, *, value, failure, continuation=False
    ):
        if self.first_rule == "success":
            return [f"{first} == {success}"]
        if self.first_rule == "same_error":
            return [f"{first} == Result[{value(first)}, {error}]"]
        if self.first_rule == "same_success" and continuation:
            return [f"{first} == Result[{success}, {failure(first)}]"]
        return []

    def second_result(self, success, error):
        return {
            "success": success,
            "error": error,
            "source": f"Result[{success}, {error}]",
        }[self.second_rule]

    @staticmethod
    def native_error(first, second=None, *, pure_first=False, pure_second=False):
        # Emitters decide which Never evidence is available before specialization.
        if second is None or pure_second:
            return first
        if pure_first:
            return second
        return f"_CommonError[{first}, {second}]"

    @staticmethod
    def error_constraint(first, second):
        return f"({first} == Never or {second} == Never or {first} == {second})"


RESULT_OPERATIONS = {
    op.name: op
    for op in (
        *(
            ResultOperation(
                op.name,
                (ResultCallback(op.mode, "none" if op.factory else "success"),),
                output=op.result_output,
                sequence=True,
            )
            for op in SEQUENCING.values()
        ),
        ResultOperation(
            "ensure",
            (
                ResultCallback("borrow", "success", "predicate"),
                ResultCallback("borrow", "success", "make_error"),
            ),
            second_rule="error",
        ),
        ResultOperation(
            "recover", (ResultCallback("owned", "error"),), first_rule="success"
        ),
        ResultOperation("tap_err", (ResultCallback("borrow", "error"),)),
        ResultOperation(
            "recover_if",
            (
                ResultCallback("borrow", "error", "predicate"),
                ResultCallback("owned", "error"),
            ),
            second_rule="success",
        ),
        ResultOperation(
            "or_else_if",
            (
                ResultCallback("borrow", "error", "predicate"),
                ResultCallback("owned", "error"),
            ),
            second_rule="source",
        ),
        ResultOperation(
            "flat_tap_err",
            (ResultCallback("borrow", "error"),),
            first_rule="same_error",
        ),
        ResultOperation(
            "attempt_tap", (ResultCallback("borrow", "whole"),), first_rule="same_error"
        ),
        ResultOperation("map_err", (ResultCallback("owned", "error"),), output="error"),
        ResultOperation(
            "or_else",
            (ResultCallback("owned", "error"),),
            output="first",
            first_rule="same_success",
        ),
        ResultOperation(
            "map_both",
            (
                ResultCallback("owned", "success", "on_ok"),
                ResultCallback("owned", "error", "on_err"),
            ),
            output="both",
            outcome=True,
        ),
        ResultOperation(
            "redeem",
            (
                ResultCallback("owned", "success", "on_ok"),
                ResultCallback("owned", "error", "on_err"),
            ),
            output="success",
            outcome=True,
        ),
        ResultOperation(
            "redeem_with",
            (
                ResultCallback("owned", "success", "on_ok"),
                ResultCallback("owned", "error", "on_err"),
            ),
            output="first",
            outcome=True,
        ),
    )
}
