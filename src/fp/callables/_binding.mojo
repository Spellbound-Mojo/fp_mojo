"""A consumed argument bundle and a borrowed callback form one OnceThunk.

The caller supplies the native signature bridge. This owner invokes once and
moves the entire bundle, including its origins, without copying captured state.
"""
from .protocols import OnceThunk

@fieldwise_init
struct _BoundThunk[B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                   F: Movable & Deinitable, o: ImmOrigin,
                   apply: def(F, var B) raises E thin -> R](OnceThunk):
    var arguments: Self.B
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.R
    comptime Error = Self.E
    def call_once(deinit self) raises Self.E -> Self.R:
        return Self.apply(self.function[], self.arguments^)

