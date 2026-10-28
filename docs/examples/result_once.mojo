"""Move a formatter into one Result transformation and consume the final handler."""
from fp.callables import OnceUnary, Unary, MutableUnary, BorrowMutableCallable, mut_ref
from fp.data import Result, Ok, Err


@fieldwise_init
struct Format(OnceUnary):
    var prefix: String
    comptime Arg = Int
    comptime Out = String
    def call_once(deinit self, var number: Int) -> String:
        self.prefix += String(number)
        return self.prefix^


@fieldwise_init
struct Show[T: Writable & Movable & Deinitable](OnceUnary):
    var label: String
    comptime Arg = Self.T
    comptime Out = Int
    def call_once(deinit self, var value: Self.T) -> Int:
        print(self.label, value)
        return 0


@fieldwise_init
struct Count(MutableUnary, BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Int
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def invoke_mut(mut self, ref value: Int) -> Int:
        self.calls += 1
        return value
    def call_mut(mut self, var value: Int) -> Int:
        return self.invoke_mut(value)


@fieldwise_init
struct Offset(Unary):
    comptime Arg = Int
    comptime Out = Int
    var amount: Int
    def call(self, var value: Int) -> Int:
        return value + self.amount


def double(value: Int) -> Int:
    return value * 2


def main():
    var formatter = Format(String('value '))
    var value: Result[Int, Int] = Ok(12)
    var result = value^.map(formatter^)
    _ = result^.fold_owned(Show[String](String('used once:')), Show[Int](String('error:')))
    var on_ok = Count(0)
    var on_err = Count(0)
    print("folded:", Result[Int,Int](Ok(12)).fold_owned(mut_ref(on_ok),mut_ref(on_err)))
    print("handler calls:", on_ok.calls, on_err.calls)
    var subject = Result[Int,Int](Ok(9))
    print("borrowed fold:", subject.fold(mut_ref(on_ok),mut_ref(on_err)))
    print("still ok:", subject.is_ok())
    var shared = Offset(10)
    print("mixed error:", Result[Int,Int](Err(12)).fold_owned(shared,mut_ref(on_err)))
    print("mixed success:", Result[Int,Int](Ok(12)).fold_owned(shared,mut_ref(on_err)))
    print("native success:", Result[Int,Int](Ok(12)).fold_owned(double,shared))
    print("native error:", Result[Int,Int](Err(12)).fold(mut_ref(on_ok),double))
