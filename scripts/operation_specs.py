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
class EffectReduction:
    """Select the existing step and stopping rule for an effectful reduction."""

    name: str
    mode: str
    accumulation: str
    all_values: bool = False
    contract_name: str = ""

    @property
    def borrowing(self):
        return self.mode == "borrow"

    @property
    def seeded(self):
        return self.accumulation == "fold"

    @property
    def mapped(self):
        return self.accumulation == "monoid"

    @property
    def searching(self):
        return self.accumulation == "present"

    def bind(self, family, source, element, callback, build, result, *,
             accumulator="", initial="", monoid="", retained=""):
        # Public contracts describe the original callback. The execution plan
        # may then wrap it for retention or accumulation without changing that
        # admission identity.
        contract_arguments = [family, *([monoid] if self.mapped else []), source, callback]
        contract = (f"{self.contract_name}[{', '.join(contract_arguments)}]"
                    if self.contract_name else None)
        # The caller supplies the exact retention alias used by its admission
        # surface. Both aliases delegate to the same existing runtime owner.
        if self.accumulation == "bool":
            step = f"_PredicateStep[{callback}]"
            policy = f"_BoolLive[{self.all_values}]"
            initial, payload = str(self.all_values), "Bool"
            build = f"{step}({build})"
        elif self.searching:
            selected = element if self.borrowing else f"_ListElement[{family}.Element[{result}]]"
            if self.borrowing:
                if not retained:
                    raise ValueError("A borrowing effect search needs its retention adapter")
                callback, build = retained, f"{retained}({build})"
            step = f"_SearchStep[{selected}, {callback}]"
            policy, initial = f"_FirstPresent[{selected}]", f"Optional[{selected}]()"
            payload = "Bool" if self.borrowing else f"Optional[{selected}]"
            build = f"{step}({build})"
        elif self.seeded:
            if not accumulator or not initial:
                raise ValueError("An effectful fold needs its accumulator type and initial value")
            step, policy, payload = callback, f"_AllLive[{accumulator}]", accumulator
        elif self.mapped:
            if not monoid:
                raise ValueError("An effectful mapped fold needs its monoid")
            step, policy = f"_FoldMappedStep[{family}, {monoid}, {callback}]", f"_AllLive[{monoid}.Value]"
            payload = f"{monoid}.Value"
        else:
            raise ValueError(f"Unknown effectful accumulation policy: {self.accumulation}")
        return EffectReductionPlan(family, source, callback, step, policy,
                                   initial, build, payload, monoid, contract)


@dataclass(frozen=True)
class EffectReductionPlan:
    family: str
    source: str
    callback: str
    step: str
    policy: str
    initial: str
    build: str
    payload: str
    monoid: str
    contract: str | None

    @property
    def types(self):
        return f"_EffectFold[{self.family}, {self.source}, {self.step}, {self.policy}]"

    @property
    def result(self):
        return f"{self.types}.Out"

    @property
    def error(self):
        error = f"{self.types}.Error"
        return f"_CommonError[{self.monoid}.Error, {error}]" if self.monoid else error

    def invoke(self, error, value):
        if self.monoid:
            return (f"_fold_map_effect[{self.family}, {self.monoid}, {self.source}, "
                    f"{self.callback}, {error}]({self.build}, {value})")
        return (f"_fold_effect[{self.family}, {self.source}, {self.step}, {self.policy}, "
                f"{error}]({self.build}, {self.initial}, {value})")


EFFECT_REDUCTIONS = {
    op.name: op
    for op in (
        EffectReduction("fold_effect", "binary", "fold", contract_name="FoldContract"),
        EffectReduction("any_effect", "borrow", "bool"),
        EffectReduction("all_effect", "borrow", "bool", all_values=True),
        EffectReduction("find_effect", "borrow", "present", contract_name="FindContract"),
        EffectReduction("find_map_effect", "owned", "present", contract_name="FindMapContract"),
        EffectReduction("fold_map_effect", "owned", "monoid", contract_name="FoldMapContract"),
    )
}


@dataclass(frozen=True)
class EffectChoice:
    """Existing conditional continuation and its exact branch-error probe."""

    family: str
    source: str
    left: str
    right: str
    left_result: str
    right_result: str
    left_error: str
    right_error: str

    @property
    def common_error(self):
        # Only literal Never is simplified. Evidence from a generic associated
        # error, and admission of that error, remain with each surface.
        if self.left_error == "Never":
            return self.right_error
        if self.right_error == "Never":
            return self.left_error
        return f"_CommonError[{self.left_error}, {self.right_error}]"

    @property
    def callback(self):
        return f"_IfEffect[{self.family}, {self.left}, {self.right}]"

    @property
    def result(self):
        return f"{self.family}.Bound[{self.source}, {self.callback}]"

    @property
    def error(self):
        joined = f"{self.family}._Joined[{self.left_result}, {self.right_result}]"
        probe = f"_ErrorProbe[Bool, {joined}, {self.common_error}]"
        return f"{self.family}.BindError[{self.source}, {probe}]"

    def invoke(self, error, value, left, right):
        return (f"_if_effect[{self.family}, {self.source}, {self.left}, {self.right}, "
                f"{error}]({value}, {left}, {right})")


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
class OperationCallback:
    mode: str
    payload: str
    argument: str = "function"

    def input(self, success, error, *, whole=None):
        if self.payload == "whole":
            if whole is None:
                raise ValueError(
                    "A whole-outcome callback needs its surface's carrier type"
                )
            return whole
        return {"success": success, "error": error, "none": ""}[self.payload]


def native_errors_compatible(first, second):
    """The existing two-callback native-error rule, without stored errors."""
    return f"({first} == Never or {second} == Never or {first} == {second})"


_ERROR_CALLBACKS = {
    "recovery": (OperationCallback("owned", "error"),),
    "conditional": (
        OperationCallback("borrow", "error", "predicate"),
        OperationCallback("owned", "error"),
    ),
    "observation": (OperationCallback("borrow", "error"),),
    "ensure": (
        OperationCallback("borrow", "success", "predicate"),
        OperationCallback("borrow", "success", "make_error"),
    ),
    "redeem": (
        OperationCallback("owned", "success", "on_ok"),
        OperationCallback("owned", "error", "on_err"),
    ),
    "whole_observation": (OperationCallback("borrow", "whole"),),
}


@dataclass(frozen=True)
class ErrorOperation:
    """Shared callback roles and value/effect choices, without family admission.

    Result carrier constraints and family construction/deferred errors belong
    to their respective emitters. Generic handler helpers name existing Mojo
    continuations; this descriptor does not generate an execution mechanism.
    """

    name: str
    category: str
    effect: bool = False

    @property
    def callbacks(self):
        return _ERROR_CALLBACKS[self.category]

    def handler(self, family, callback):
        if self.category not in ("recovery", "conditional"):
            raise ValueError(f"{self.name} does not recover an error")
        return callback if self.effect else f"_Recovered[{family}, {callback}]"

    def handler_value(self, family, callback, value):
        return value if self.effect else f"{self.handler(family, callback)}({value})"

    def handler_carrier(self, family, result):
        return result if self.effect else f"{family}.Pure[{result}]"


# Order preserves each generic surface's existing overload/documentation order.
ERROR_OPERATIONS = {
    op.name: op
    for op in (
        ErrorOperation("or_else", "recovery", effect=True),
        ErrorOperation("recover", "recovery"),
        ErrorOperation("recover_if", "conditional"),
        ErrorOperation("or_else_if", "conditional", effect=True),
        ErrorOperation("tap_err", "observation"),
        ErrorOperation("flat_tap_err", "observation", effect=True),
        ErrorOperation("ensure", "ensure"),
        ErrorOperation("redeem", "redeem"),
        ErrorOperation("redeem_with", "redeem", effect=True),
        ErrorOperation("attempt_tap", "whole_observation", effect=True),
    )
}


def error_operations(category):
    return (op for op in ERROR_OPERATIONS.values() if op.category == category)


@dataclass(frozen=True)
class ResultOperation:
    name: str
    callbacks: tuple[OperationCallback, ...]
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

    error_constraint = staticmethod(native_errors_compatible)

    @classmethod
    def from_error(cls, name):
        """Translate common callback policy to Result-specific carrier checks."""
        operation = ERROR_OPERATIONS[name]
        rules = {
            "recovery": dict(
                output="first" if operation.effect else "source",
                first_rule="same_success" if operation.effect else "success",
            ),
            "conditional": dict(
                second_rule="source" if operation.effect else "success"
            ),
            "observation": dict(first_rule="same_error" if operation.effect else ""),
            "ensure": dict(second_rule="error"),
            "redeem": dict(
                output="first" if operation.effect else "success", outcome=True
            ),
            "whole_observation": dict(first_rule="same_error"),
        }[operation.category]
        return cls(name, operation.callbacks, **rules)


RESULT_OPERATIONS = {
    op.name: op
    for op in (
        *(
            ResultOperation(
                op.name,
                (OperationCallback(op.mode, "none" if op.factory else "success"),),
                output=op.result_output,
                sequence=True,
            )
            for op in SEQUENCING.values()
        ),
        ResultOperation.from_error("ensure"),
        ResultOperation.from_error("recover"),
        ResultOperation.from_error("tap_err"),
        ResultOperation.from_error("recover_if"),
        ResultOperation.from_error("or_else_if"),
        ResultOperation.from_error("flat_tap_err"),
        ResultOperation.from_error("attempt_tap"),
        ResultOperation(
            "map_err", (OperationCallback("owned", "error"),), output="error"
        ),
        ResultOperation.from_error("or_else"),
        ResultOperation(
            "map_both",
            (
                OperationCallback("owned", "success", "on_ok"),
                OperationCallback("owned", "error", "on_err"),
            ),
            output="both",
            outcome=True,
        ),
        ResultOperation.from_error("redeem"),
        ResultOperation.from_error("redeem_with"),
    )
}
