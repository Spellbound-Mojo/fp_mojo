"""One-shot keyword arguments inferred before native callback admission.

The first argument is borrowed mutably; the second and keyword values are
owned. Construction evaluates arguments but never invokes a callback. Running
consumes the bundle and borrows the callback for that call only. Empty packs
need K explicitly, or an expanded typed StringDict, before callback matching.
"""
from fp._binding_staged import KeywordCall
from fp.data import Result
from std.collections import StringDict

@fieldwise_init
struct _KeywordArguments[A: Movable & Deinitable, B: Movable & Deinitable,
                K: Movable & Deinitable, E: Movable & Deinitable,
                o: MutOrigin](Movable):
    # Retain the original mutable origin; never widen it for stored arguments.
    var first: Pointer[Self.A, Self.o]
    var second: Self.B
    var values: StringDict[Self.K]

    # Signature adapters only: KeywordCall and Result still own execution.
    def run[R: Movable & Deinitable, q: ImmOrigin, //,
            F: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) -> R](deinit self, ref[q] function: F) -> Result[R, Never]:
        return KeywordCall[Self.A, Self.B, Self.K, Self.E].of(function).run(self.first[], self.second^, **self.values^)

    def run[R: Movable & Deinitable, q: ImmOrigin, //,
            F: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E -> R](deinit self, ref[q] function: F) -> Result[R, Self.E]:
        return KeywordCall[Self.A, Self.B, Self.K, Self.E].of(function).run(self.first[], self.second^, **self.values^)

    # Thin Never functions need their literal ABI at admission as well as call.
    def run(deinit self, function: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin) -> Result[type_of(None), Never]:
        return KeywordCall[Self.A, Self.B, Self.K, Self.E].of(function).run(self.first[], self.second^, **self.values^)

    def run[R: Movable & Deinitable, //](deinit self, function: def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin -> R) -> Result[R, Never]:
        return KeywordCall[Self.A, Self.B, Self.K, Self.E].of(function).run(self.first[], self.second^, **self.values^)

struct Capture[E: Movable & Deinitable]:
    @staticmethod
    def kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, o: MutOrigin, //](ref[o] first: A, var second: B, /, var **values: K) -> _KeywordArguments[A, B, K, Self.E, o]:
        return _KeywordArguments[A, B, K, Self.E, o](Pointer(to=first), second^, values^)

