"""Instrumented mapping-only policy using native Result storage."""
from fp.algebra import ErrorMapping, ResultFamily
from fp.callables import UnaryContract, Unary
from fp.data import Result
from std.builtin.rebind import downcast, rebind_var

struct MappingOnly[E: Movable & Deinitable, throws: Bool = False, admitted: Bool = True](ErrorMapping):
    comptime Base = ResultFamily[Self.E]
    comptime Failure = Self.E
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapCompatible[V,F]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    comptime DefaultErrorTarget[A: Movable & Deinitable, G: Movable & Deinitable] = MappingOnly[G,Self.throws,Self.admitted]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self.admitted and Target == Self.DefaultErrorTarget[F.Out,G.Out] and Self.Base.BimapCompatible[ResultFamily[G.Out],V,F,G]
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Result[F.Out,G.Out]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Int if Self.throws else Self.Base.BimapError[ResultFamily[G.Out],V,F,G]
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var source: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return Self.Base.map(function^,source^)
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var on_ok: F, var on_err: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        comptime assert Self.BimapCompatible[Target,V,F,G]
        comptime if Self.throws:
            comptime assert Self.BimapError[Target,V,F,G] == Int
            raise rebind_var[Self.BimapError[Target,V,F,G]](Int(763))
        else:
            comptime assert Self.BimapError[Target,V,F,G] == Self.Base.BimapError[ResultFamily[G.Out],V,F,G]
            try:
                return Self.Base.bimap[ResultFamily[G.Out]](on_ok^,on_err^,source^)
            except error:
                comptime assert Self.BimapError[Target,V,F,G] == type_of(error)
                raise rebind_var[Self.BimapError[Target,V,F,G]](error^)



@fieldwise_init
struct Show(Unary):
    comptime Arg = Int
    comptime Out = String
    def call(self, var value: Int) -> String: return String(value)

@fieldwise_init
struct Size(Unary):
    comptime Arg = String
    comptime Out = Int
    def call(self, var value: String) -> Int: return value.byte_length()


trait EnvelopeType:
    comptime Value: Movable & Deinitable

@fieldwise_init
struct Envelope[A: Movable & Deinitable, E: Movable & Deinitable](Movable, EnvelopeType):
    var value: Result[Self.A, Self.E]
    comptime Value = Self.A
    def take(deinit self) -> Result[Self.A,Self.E]: return self.value^

struct EnvelopeFamily[E: Movable & Deinitable](ErrorMapping):
    comptime Base = ResultFamily[Self.E]
    comptime Failure = Self.E
    comptime Element[V: Movable & Deinitable] = downcast[V,EnvelopeType].Value
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = V == Envelope[Self.Element[V],Self.E]
    comptime DefaultErrorTarget[A: Movable & Deinitable, G: Movable & Deinitable] = EnvelopeFamily[G]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Envelope[F.Out,Self.E]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.ErrorCarrierCompatible[V]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Target == EnvelopeFamily[G.Out] and Self.Base.BimapCompatible[ResultFamily[G.Out],Result[F.Arg,Self.E],F,G]
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Envelope[F.Out,G.Out]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self.Base.BimapError[ResultFamily[G.Out],Result[F.Arg,Self.E],F,G]
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var source: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        var wrapped = rebind_var[Envelope[F.Arg,Self.E]](source^)
        return Envelope(Self.Base.map(function^,wrapped^.take()))
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var on_ok: F, var on_err: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        var wrapped = rebind_var[Envelope[F.Arg,Self.E]](source^)
        return Envelope(Self.Base.bimap[ResultFamily[G.Out]](on_ok^,on_err^,wrapped^.take()))

struct FixedMapping(ErrorMapping):
    comptime Base = ResultFamily[String]
    comptime Failure = String
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self.Base.ErrorCarrierCompatible[V]
    comptime DefaultErrorTarget[A: Movable & Deinitable, E: Movable & Deinitable] = Self
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Target == Self and Self.Base.BimapCompatible[ResultFamily[G.Out],V,F,G]
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self.Base.Bimapped[ResultFamily[G.Out],V,F,G]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self.Base.BimapError[ResultFamily[G.Out],V,F,G]
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return Self.Base.map(f^,source^)
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var f: F, var g: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        return Self.Base.bimap[ResultFamily[G.Out]](f^,g^,source^)
