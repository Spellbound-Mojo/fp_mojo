# error: no matching method in call to 'ensure'
from fp.algebra import ApplicativeError, Monad, ResultFamily
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from fp.functions import pipeline
from fp.data import Result, Ok
from std.builtin.rebind import rebind_var
struct Family[fail_raises: Bool = False, bind_raises: Bool = False, admitted: Bool = True](ApplicativeError, Monad):
    comptime Base = ResultFamily[String]
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Failure = String
    comptime Failed[A: Movable & Deinitable] = Self.Base.Failed[A]
    comptime FailError[A: Movable & Deinitable] = Int if Self.fail_raises else Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.HandleError[V,H]
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base._ErrorCarrier[V]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Bound[V,F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int if Self.bind_raises else F.Error
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.admitted and Self.Base.BindCompatible[V,F]
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(f^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(f^,left^,right^)
    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) raises Self.FailError[A] -> Self.Failed[A]:
        comptime if Self.fail_raises:
            comptime assert Self.FailError[A] == Int
            raise rebind_var[Self.FailError[A]](Int(731))
        else: return Self.Base.fail[A](String("custom:") + error)
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V,H] -> Self.Handled[V,H]: return Self.Base.or_else(handler^,source^)
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises Self.BindError[V,F] -> Self.Bound[V,F]:
        comptime if Self.bind_raises:
            comptime assert Self.BindError[V,F] == Int
            raise rebind_var[Self.BindError[V,F]](Int(733))
        else:
            comptime assert Self.BindError[V,F] == F.Error
            try: return Self.Base.flat_map(f^,source^)
            except error:
                comptime assert Self.BindError[V,F] == type_of(error)
                raise rebind_var[Self.BindError[V,F]](error^)

def predicate(value: Int) -> Bool: return False
def factory(value: Int) -> String: return String(value)
def main():
    _ = pipeline[Family[False,False,False]](Result[Int,String](Ok(1))).ensure(predicate,factory)
