from fp.algebra import OptionalFamily, MapContract, BindContract, CombineContract
from fp.callables import UnaryContract, BinaryContract, ThunkContract, Binary, OnceThunk

@fieldwise_init
struct MissingMap(UnaryContract, Movable):
    comptime Arg = Int
    comptime Out = Int

@fieldwise_init
struct MissingBind(UnaryContract, Movable):
    comptime Arg = Int
    comptime Out = Optional[Int]

@fieldwise_init
struct MissingBinary(BinaryContract, Movable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int

@fieldwise_init
struct MissingThunk(ThunkContract, Movable):
    comptime Out = Optional[Int]

@fieldwise_init
struct Add(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var left: Int, var right: Int) -> Int:
        return left + right

@fieldwise_init
struct Next(OnceThunk):
    comptime Out = Optional[Int]
    def call_once(deinit self) -> Self.Out:
        return Optional(7)


from fp.algebra import Functor, Monad, Applicative, map, flat_map, map2_lazy
from fp.callables import OnceUnary
from std.testing import assert_equal

@fieldwise_init
struct Echo(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int: return value

@fieldwise_init
struct Present(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var value: Int) -> Self.Out: return Optional(value)

def mapped[I: Functor,V: Movable & Deinitable,F: UnaryContract & Movable & Deinitable](var source:V,var function:F) raises MapContract[I,V,F].Error -> MapContract[I,V,F].Out where MapContract[I,V,F].Compatible:
    return map[I](function^,source^)

def checked_map[I: Functor,V: Movable & Deinitable,F: UnaryContract & Movable & Deinitable](var source:V,var function:F) raises MapContract[I,V,F].Error -> MapContract[I,V,F].Out where MapContract[I,V,F].InvocationCompatible:
    return mapped[I](source^,function^)

def expanded_map[I: Functor,V: Movable & Deinitable,F: UnaryContract & Movable & Deinitable](var source:V,var function:F) raises MapContract[I,V,F].Error -> MapContract[I,V,F].Out where I.Element[V] == F.Arg and I.MapCompatible[V,F]:
    return mapped[I](source^,function^)

def bound[I: Monad,V: Movable & Deinitable,F: UnaryContract & Movable & Deinitable](var source:V,var function:F) raises BindContract[I,V,F].Error -> BindContract[I,V,F].Out where BindContract[I,V,F].Compatible:
    return flat_map[I](function^,source^)

def checked_bind[I: Monad,V: Movable & Deinitable,F: UnaryContract & Movable & Deinitable](var source:V,var function:F) raises BindContract[I,V,F].Error -> BindContract[I,V,F].Out where BindContract[I,V,F].InvocationCompatible:
    return bound[I](source^,function^)

def expanded_bind[I: Monad,V: Movable & Deinitable,F: UnaryContract & Movable & Deinitable](var source:V,var function:F) raises BindContract[I,V,F].Error -> BindContract[I,V,F].Out where I.Element[V] == F.Arg and I.BindCompatible[V,F]:
    return bound[I](source^,function^)

def combined[I: Applicative,V: Movable & Deinitable,F: BinaryContract & Movable & Deinitable,R: ThunkContract & Movable & Deinitable](var source:V,var function:F,var right:R) raises CombineContract[I,V,F,R].Error -> CombineContract[I,V,F,R].Out where CombineContract[I,V,F,R].Compatible:
    return map2_lazy[I](function^,source^,right^)

def checked_combine[I: Applicative,V: Movable & Deinitable,F: BinaryContract & Movable & Deinitable,R: ThunkContract & Movable & Deinitable](var source:V,var function:F,var right:R) raises CombineContract[I,V,F,R].Error -> CombineContract[I,V,F,R].Out where CombineContract[I,V,F,R].InvocationCompatible:
    return combined[I](source^,function^,right^)

def expanded_combine[I: Applicative,V: Movable & Deinitable,F: BinaryContract & Movable & Deinitable,R: ThunkContract & Movable & Deinitable](var source:V,var function:F,var right:R) raises CombineContract[I,V,F,R].Error -> CombineContract[I,V,F,R].Out where CombineContract[I,V,F,R].InputCompatible and CombineContract[I,V,F,R].FamilyCompatible:
    return combined[I](source^,function^,right^)

def forwarding() raises:
    assert_equal(checked_map[OptionalFamily](Optional(3),Echo()).value(),3)
    assert_equal(expanded_map[OptionalFamily](Optional(3),Echo()).value(),3)
    assert_equal(checked_bind[OptionalFamily](Optional(3),Present()).value(),3)
    assert_equal(expanded_bind[OptionalFamily](Optional(3),Present()).value(),3)
    assert_equal(checked_combine[OptionalFamily](Optional(3),Add(),Next()).value(),10)
    assert_equal(expanded_combine[OptionalFamily](Optional(3),Add(),Next()).value(),10)
