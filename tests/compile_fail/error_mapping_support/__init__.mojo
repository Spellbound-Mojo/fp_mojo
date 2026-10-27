"""Independent admission probe: source can permit targets that reject its output."""
from fp.algebra import ErrorMapping, ResultFamily
from fp.callables import UnaryContract
from fp.data import Result
from std.builtin.rebind import downcast

trait AbsentShape:
    comptime Payload: Movable & Deinitable

struct Probe[E: Movable & Deinitable, mode: Int = 0](ErrorMapping):
    comptime Base = ResultFamily[Self.E]
    comptime Failure = Self.E
    comptime Element[V: Movable & Deinitable] = (downcast[V,AbsentShape].Payload if Self.mode == 2 else (Bool if Self.mode == 3 else Self.Base.Element[V]))
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = False if Self.mode == 2 else Self.Base.ErrorCarrierCompatible[V]
    comptime DefaultErrorTarget[A: Movable & Deinitable, G: Movable & Deinitable] = Probe[G,Self.mode]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self.mode != 1
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Result[F.Out,G.Out]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self.Base.BimapError[ResultFamily[G.Out],V,F,G]
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return Self.Base.map(f^,source^)
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var f: F, var g: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        return Self.Base.bimap[ResultFamily[G.Out]](f^,g^,source^)
