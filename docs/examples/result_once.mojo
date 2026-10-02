"""Move a formatter into one Result transformation and consume the final handler."""
from fp.callables import OnceUnary
from fp.data import Result, Ok


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


def main():
    var formatter = Format(String('value '))
    var value: Result[Int, Int] = Ok(12)
    var result = value^.map(formatter^)
    _ = result^.fold_owned_once(Show[String](String('used once:')), Show[Int](String('error:')))
